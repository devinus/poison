defmodule Poison.SyntaxError do
  defexception [:message, :token, :pos]

  def exception(opts) do
    message = if token = opts[:token] do
      "Unexpected token at position #{opts[:pos]}: #{token}"
    else
      "Unexpected end of input at position #{opts[:pos]}"
    end

    %Poison.SyntaxError{message: message, token: token}
  end
end

defmodule Poison.Parser do
  @moduledoc """
  An ECMA 404 conforming JSON parser.

  See: http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
  """

  if Application.get_env(:poison, :native) do
    @compile :native
  end

  use Bitwise

  alias Poison.SyntaxError

  @type t :: nil | true | false | list | float | integer | String.t | map

  @spec parse(iodata, Keyword.t) :: {:ok, t} | {:error, :invalid}
    | {:error, {:invalid, String.t}}
  def parse(iodata, options \\ []) do
    string = IO.iodata_to_binary(iodata)
    {rest, pos} = skip_whitespace(string, 0)
    {value, pos, rest} = value(rest, pos, options[:keys])
    case skip_whitespace(rest, pos) do
      {"", _pos} -> {:ok, value}
      {other, pos} -> syntax_error(other, pos)
    end
  catch
    {:invalid, pos} ->
      {:error, :invalid, pos}
    {:invalid, token, pos} ->
      {:error, {:invalid, token, pos}}
  end

  @spec parse!(iodata, Keyword.t) :: t
  def parse!(iodata, options \\ []) do
    case parse(iodata, options) do
      {:ok, value} ->
        value
      {:error, :invalid, pos} ->
        raise SyntaxError, pos: pos
      {:error, {:invalid, token, pos}} ->
        raise SyntaxError, token: token, pos: pos
    end
  end

  defp value("\"" <> rest, pos, _keys) do
    string_continue(rest, pos+1, [])
  end
  defp value("{" <> rest, pos, keys) do
    {rest, pos} = skip_whitespace(rest, pos+1)
    object_pairs(rest, pos, keys, [])
  end
  defp value("[" <> rest, pos, keys) do
    {rest, pos} = skip_whitespace(rest, pos+1)
    array_values(rest, pos, keys, [])
  end

  defp value("null" <> rest, pos, _keys),  do: {nil, pos+4, rest}
  defp value("true" <> rest, pos, _keys),  do: {true, pos+4, rest}
  defp value("false" <> rest, pos, _keys), do: {false, pos+5, rest}

  defp value(<<char, _ :: binary>> = string, pos, _keys) when char in '-0123456789' do
    number_start(string, pos)
  end

  defp value(other, pos, _keys), do: syntax_error(other, pos)

  ## Objects

  defp object_pairs("\"" <> rest, pos, keys, acc) do
    {name, pos, rest} = string_continue(rest, pos+1, [])
    {value, pos, rest} = case skip_whitespace(rest, pos) do
      {":" <> rest, pos} ->
        {rest, pos} = skip_whitespace(rest, pos+1)
        value(rest, pos, keys)
      {other, pos} ->
        syntax_error(other, pos)
    end

    acc = [{object_name(name, keys), value} | acc]
    case skip_whitespace(rest, pos) do
      {"," <> rest, pos} ->
        {rest, pos} = skip_whitespace(rest, pos+1)
        object_pairs(rest, pos, keys, acc)
      {"}" <> rest, pos} ->
        {:maps.from_list(acc), pos+1, rest}
      {other, pos} ->
        syntax_error(other, pos)
    end
  end

  defp object_pairs("}" <> rest, pos, _, []) do
    {:maps.new, pos+1, rest}
  end

  defp object_pairs(other, pos, _, _), do: syntax_error(other, pos)

  defp object_name(name, :atoms),  do: String.to_atom(name)
  defp object_name(name, :atoms!), do: String.to_existing_atom(name)
  defp object_name(name, _keys),   do: name

  ## Arrays

  defp array_values("]" <> rest, pos, _, []) do
    {[], pos+1, rest}
  end

  defp array_values(string, pos, keys, acc) do
    {value, pos, rest} = value(string, pos, keys)

    acc = [value | acc]
    case skip_whitespace(rest, pos) do
      {"," <> rest, pos} ->
        {rest, pos} = skip_whitespace(rest, pos+1)
        array_values(rest, pos, keys, acc)
      {"]" <> rest, pos} ->
        {:lists.reverse(acc), pos+1, rest}
      {other, pos} ->
        syntax_error(other, pos)
    end
  end

  ## Numbers

  defp number_start("-" <> rest, pos) do
    case rest do
      "0" <> rest -> number_frac(rest, pos+2, ["-0"])
      rest -> number_int(rest, pos+1, [?-])
    end
  end

  defp number_start("0" <> rest, pos) do
    number_frac(rest, pos+1, [?0])
  end

  defp number_start(string, pos) do
    number_int(string, pos, [])
  end

  defp number_int(<<char, _ :: binary>> = string, pos, acc) when char in '123456789' do
    {digits, pos, rest} = number_digits(string, pos)
    number_frac(rest, pos, [acc, digits])
  end

  defp number_int(other, pos, _), do: syntax_error(other, pos)

  defp number_frac("." <> rest, pos, acc) do
    {digits, pos, rest} = number_digits(rest, pos+1)
    number_exp(rest, true, pos, [acc, ?., digits])
  end

  defp number_frac(string, pos, acc) do
    number_exp(string, false, pos, acc)
  end

  defp number_exp(<<e>> <> rest, frac, pos, acc) when e in 'eE' do
    e = if frac, do: ?e, else: ".0e"
    case rest do
      "-" <> rest -> number_exp_continue(rest, pos+2, [acc, e, ?-])
      "+" <> rest -> number_exp_continue(rest, pos+2, [acc, e])
      rest -> number_exp_continue(rest, pos+1, [acc, e])
    end
  end

  defp number_exp(string, frac, pos, acc) do
    {number_complete(acc, frac), pos, string}
  end

  defp number_exp_continue(rest, pos, acc) do
    {digits, pos, rest} = number_digits(rest, pos)
    {number_complete([acc, digits], true), pos, rest}
  end

  defp number_complete(iolist, false) do
    iolist |> IO.iodata_to_binary |> String.to_integer
  end

  defp number_complete(iolist, true) do
    iolist |> IO.iodata_to_binary |> String.to_float
  end

  defp number_digits(<<char>> <> rest = string, pos) when char in '0123456789' do
    count = number_digits_count(rest, 1)
    <<digits :: binary-size(count), rest :: binary>> = string
    {digits, pos+count, rest}
  end

  defp number_digits(other, pos), do: syntax_error(other, pos)

  defp number_digits_count(<<char>> <> rest, acc) when char in '0123456789' do
    number_digits_count(rest, acc+1)
  end

  defp number_digits_count(_, acc), do: acc

  ## Strings

  defp string_continue("\"" <> rest, pos, acc) do
    {IO.iodata_to_binary(acc), pos+1, rest}
  end

  defp string_continue("\\" <> rest, pos, acc) do
    string_escape(rest, pos, acc)
  end

  defp string_continue("", pos, _), do: throw({:invalid, pos})

  defp string_continue(string, pos, acc) do
    {count, pos} = string_chunk_size(string, pos, 0)
    <<chunk :: binary-size(count), rest :: binary>> = string
    string_continue(rest, pos, [acc, chunk])
  end

  for {seq, char} <- Enum.zip('"\\ntr/fb', '"\\\n\t\r/\f\b') do
    defp string_escape(<<unquote(seq)>> <> rest, pos, acc) do
      string_continue(rest, pos+1, [acc, unquote(char)])
    end
  end

  # http://www.ietf.org/rfc/rfc2781.txt
  # http://perldoc.perl.org/Encode/Unicode.html#Surrogate-Pairs
  # http://mathiasbynens.be/notes/javascript-encoding#surrogate-pairs
  defp string_escape(<<?u, a1, b1, c1, d1, "\\u", a2, b2, c2, d2>> <> rest, pos, acc)
    when a1 in 'dD' and a2 in 'dD'
    and (b1 in '89abAB')
    and (b2 in ?c..?f or b2 in ?C..?F) \
  do
    hi = List.to_integer([a1, b1, c1, d1], 16)
    lo = List.to_integer([a2, b2, c2, d2], 16)
    codepoint = 0x10000 + ((hi &&& 0x03FF) <<< 10) + (lo &&& 0x03FF)
    string_continue(rest, pos+11, [acc, <<codepoint :: utf8>>])
  end

  defp string_escape(<<?u, seq :: binary-size(4)>> <> rest, pos, acc) do
    string_continue(rest, pos+5, [acc, <<String.to_integer(seq, 16) :: utf8>> ])
  end

  defp string_escape(other, pos, _), do: syntax_error(other, pos)

  defp string_chunk_size("\"" <> _, pos, acc), do: {acc, pos}
  defp string_chunk_size("\\" <> _, pos, acc), do: {acc, pos}

  defp string_chunk_size(<<char>> <> rest, pos, acc) when char < 0x80 do
    string_chunk_size(rest, pos+1, acc+1)
  end

  defp string_chunk_size(<<codepoint :: utf8>> <> rest, pos, acc) do
    string_chunk_size(rest, pos+1, acc + string_codepoint_size(codepoint))
  end

  defp string_chunk_size(other, pos, _acc), do: syntax_error(other, pos)

  defp string_codepoint_size(codepoint) when codepoint < 0x800,   do: 2
  defp string_codepoint_size(codepoint) when codepoint < 0x10000, do: 3
  defp string_codepoint_size(_),                                  do: 4

  ## Whitespace

  defp skip_whitespace(<<char>> <> rest, pos) when char in '\s\n\t\r' do
    skip_whitespace(rest, pos+1)
  end

  defp skip_whitespace(string, pos), do: {string, pos}

  ## Errors

  defp syntax_error(<<token :: utf8>> <> _, pos) do
    throw({:invalid, <<token>>, pos})
  end

  defp syntax_error(_, pos) do
    throw({:invalid, pos})
  end
end
