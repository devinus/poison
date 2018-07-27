defmodule Poison.ParseError do
  @type t :: %__MODULE__{pos: integer, value: String.t()}

  alias Code.Identifier

  defexception pos: 0, value: nil, rest: nil

  def message(%{value: "", pos: pos}) do
    "Unexpected end of input at position #{pos}"
  end

  def message(%{value: <<token::utf8>>, pos: pos}) do
    "Unexpected token at position #{pos}: #{escape(token)}"
  end

  def message(%{value: value, pos: pos}) when is_binary(value) do
    start = pos - String.length(value)
    "Cannot parse value at position #{start}: #{inspect(value)}"
  end

  def message(%{value: value}) do
    "Unsupported value: #{inspect(value)}"
  end

  defp escape(token) do
    {value, _} = Identifier.escape(<<token::utf8>>, ?\\)
    value
  end
end

defmodule Poison.Parser do
  @moduledoc """
  An RFC 7159 and ECMA 404 conforming JSON parser.

  See: https://tools.ietf.org/html/rfc7159
  See: http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
  """

  @compile :inline
  @compile {:inline_size, 256}

  if Application.get_env(:poison, :native) do
    @compile [:native, {:hipe, [:o3]}]
  end

  use Bitwise

  alias Poison.ParseError

  @type t :: nil | true | false | list | float | integer | String.t() | map

  defmacrop stacktrace do
    if Version.compare(System.version(), "1.7.0") != :lt do
      quote do: __STACKTRACE__
    else
      quote do: System.stacktrace()
    end
  end

  def parse!(iodata, options) do
    string = IO.iodata_to_binary(iodata)
    keys = Map.get(options, :keys)
    {rest, pos} = skip_whitespace(skip_bom(string), 0)
    {value, pos, rest} = value(rest, pos, keys)

    case skip_whitespace(rest, pos) do
      {"", _pos} -> value
      {other, pos} -> syntax_error(other, pos)
    end
  rescue
    ArgumentError ->
      reraise %ParseError{value: iodata}, stacktrace()
  end

  defp value("\"" <> rest, pos, _keys) do
    string_continue(rest, pos + 1, [])
  end

  defp value("{" <> rest, pos, keys) do
    {rest, pos} = skip_whitespace(rest, pos + 1)
    object_pairs(rest, pos, keys, [])
  end

  defp value("[" <> rest, pos, keys) do
    {rest, pos} = skip_whitespace(rest, pos + 1)
    array_values(rest, pos, keys, [])
  end

  defp value("null" <> rest, pos, _keys), do: {nil, pos + 4, rest}
  defp value("true" <> rest, pos, _keys), do: {true, pos + 4, rest}
  defp value("false" <> rest, pos, _keys), do: {false, pos + 5, rest}

  defp value(<<char, _::binary>> = string, pos, _keys)
       when char in '-0123456789' do
    number_start(string, pos)
  end

  defp value(other, pos, _keys), do: syntax_error(other, pos)

  ## Objects

  defp object_pairs("\"" <> rest, pos, keys, acc) do
    {name, pos, rest} = string_continue(rest, pos + 1, [])

    {value, start, pos, rest} =
      case skip_whitespace(rest, pos) do
        {":" <> rest, start} ->
          {rest, pos} = skip_whitespace(rest, start + 1)
          {value, pos, rest} = value(rest, pos, keys)
          {value, start, pos, rest}

        {other, pos} ->
          syntax_error(other, pos)
      end

    acc = [{object_name(name, start, keys), value} | acc]

    case skip_whitespace(rest, pos) do
      {"," <> rest, pos} ->
        {rest, pos} = skip_whitespace(rest, pos + 1)
        object_pairs(rest, pos, keys, acc)

      {"}" <> rest, pos} ->
        {:maps.from_list(acc), pos + 1, rest}

      {other, pos} ->
        syntax_error(other, pos)
    end
  end

  defp object_pairs("}" <> rest, pos, _, []) do
    {:maps.new(), pos + 1, rest}
  end

  defp object_pairs(other, pos, _, _), do: syntax_error(other, pos)

  defp object_name(name, pos, :atoms!) do
    String.to_existing_atom(name)
  rescue
    ArgumentError ->
      reraise %ParseError{value: name, pos: pos}, stacktrace()
  end

  defp object_name(name, _pos, :atoms), do: String.to_atom(name)
  defp object_name(name, _pos, _keys), do: name

  ## Arrays

  defp array_values("]" <> rest, pos, _, []) do
    {[], pos + 1, rest}
  end

  defp array_values(string, pos, keys, acc) do
    {value, pos, rest} = value(string, pos, keys)

    acc = [value | acc]

    case skip_whitespace(rest, pos) do
      {"," <> rest, pos} ->
        {rest, pos} = skip_whitespace(rest, pos + 1)
        array_values(rest, pos, keys, acc)

      {"]" <> rest, pos} ->
        {:lists.reverse(acc), pos + 1, rest}

      {other, pos} ->
        syntax_error(other, pos)
    end
  end

  ## Numbers

  defp number_start("-" <> rest, pos) do
    case rest do
      "0" <> rest -> number_frac(rest, pos + 2, ["-0"])
      rest -> number_int(rest, pos + 1, [?-])
    end
  end

  defp number_start("0" <> rest, pos) do
    number_frac(rest, pos + 1, [?0])
  end

  defp number_start(string, pos) do
    number_int(string, pos, [])
  end

  defp number_int(<<char, _::binary>> = string, pos, acc)
       when char in '123456789' do
    {digits, pos, rest} = number_digits(string, pos)
    number_frac(rest, pos, [acc, digits])
  end

  defp number_int(other, pos, _), do: syntax_error(other, pos)

  defp number_frac("." <> rest, pos, acc) do
    {digits, pos, rest} = number_digits(rest, pos + 1)
    number_exp(rest, true, pos, [acc, ?., digits])
  end

  defp number_frac(string, pos, acc) do
    number_exp(string, false, pos, acc)
  end

  defp number_exp(<<e>> <> rest, frac, pos, acc) when e in 'eE' do
    e = if frac, do: ?e, else: ".0e"

    case rest do
      "-" <> rest -> number_exp_continue(rest, frac, pos + 2, [acc, e, ?-])
      "+" <> rest -> number_exp_continue(rest, frac, pos + 2, [acc, e])
      rest -> number_exp_continue(rest, frac, pos + 1, [acc, e])
    end
  end

  defp number_exp(string, frac, pos, acc) do
    {number_complete(acc, frac, pos), pos, string}
  end

  defp number_exp_continue(rest, frac, pos, acc) do
    {digits, pos, rest} = number_digits(rest, pos)
    pos = if frac, do: pos, else: pos + 2
    {number_complete([acc, digits], true, pos), pos, rest}
  end

  defp number_complete(iolist, false, _pos) do
    iolist |> IO.iodata_to_binary() |> String.to_integer()
  end

  defp number_complete(iolist, true, pos) do
    iolist |> IO.iodata_to_binary() |> String.to_float()
  rescue
    ArgumentError ->
      value = iolist |> IO.iodata_to_binary()
      reraise %ParseError{pos: pos, value: value}, stacktrace()
  end

  defp number_digits(<<char>> <> rest = string, pos)
       when char in '0123456789' do
    count = number_digits_count(rest, 1)
    <<digits::binary-size(count), rest::binary>> = string
    {digits, pos + count, rest}
  end

  defp number_digits(other, pos), do: syntax_error(other, pos)

  defp number_digits_count(<<char>> <> rest, acc) when char in '0123456789' do
    number_digits_count(rest, acc + 1)
  end

  defp number_digits_count(_, acc), do: acc

  ## Strings

  defp string_continue("\"" <> rest, pos, acc) do
    {IO.iodata_to_binary(acc), pos + 1, rest}
  end

  defp string_continue("\\" <> rest, pos, acc) do
    string_escape(rest, pos, acc)
  end

  defp string_continue("", pos, _), do: syntax_error(nil, pos)

  defp string_continue(string, pos, acc) do
    {count, pos} = string_chunk_size(string, pos, 0)
    <<chunk::binary-size(count), rest::binary>> = string
    string_continue(rest, pos, [acc, chunk])
  end

  for {seq, char} <- Enum.zip('"\\ntr/fb', '"\\\n\t\r/\f\b') do
    defp string_escape(<<unquote(seq)>> <> rest, pos, acc) do
      string_continue(rest, pos + 1, [acc, unquote(char)])
    end
  end

  defguardp is_surrogate(a1, a2, b1, b2)
            when a1 in 'dD' and a2 in 'dD' and b1 in '89abAB' and
                   (b2 in ?c..?f or b2 in ?C..?F)

  # http://www.ietf.org/rfc/rfc2781.txt
  # http://perldoc.perl.org/Encode/Unicode.html#Surrogate-Pairs
  # http://mathiasbynens.be/notes/javascript-encoding#surrogate-pairs
  defp string_escape(
         <<?u, a1, b1, c1, d1, "\\u", a2, b2, c2, d2>> <> rest,
         pos,
         acc
       )
       when is_surrogate(a1, a2, b1, b2) do
    hi = List.to_integer([a1, b1, c1, d1], 16)
    lo = List.to_integer([a2, b2, c2, d2], 16)
    codepoint = 0x10000 + ((hi &&& 0x03FF) <<< 10) + (lo &&& 0x03FF)
    string_continue(rest, pos + 11, [acc, <<codepoint::utf8>>])
  rescue
    ArgumentError ->
      value = <<"\\u", a1, b1, c1, d1, "\\u", a2, b2, c2, d2>>
      reraise %ParseError{pos: pos + 12, value: value}, stacktrace()
  end

  defp string_escape(<<?u, seq::binary-size(4)>> <> rest, pos, acc) do
    code = String.to_integer(seq, 16)
    string_continue(rest, pos + 5, [acc, <<code::utf8>>])
  rescue
    ArgumentError ->
      value = "\\u" <> seq
      reraise %ParseError{pos: pos + 6, value: value}, stacktrace()
  end

  defp string_escape(other, pos, _), do: syntax_error(other, pos)

  defp string_chunk_size("\"" <> _, pos, acc), do: {acc, pos}
  defp string_chunk_size("\\" <> _, pos, acc), do: {acc, pos}

  # Control Characters (http://seriot.ch/parsing_json.php#25)
  defp string_chunk_size(<<char>> <> _rest, pos, _acc) when char <= 0x1F do
    syntax_error(<<char>>, pos)
  end

  defp string_chunk_size(<<char>> <> rest, pos, acc) when char < 0x80 do
    string_chunk_size(rest, pos + 1, acc + 1)
  end

  defp string_chunk_size(<<codepoint::utf8>> <> rest, pos, acc) do
    string_chunk_size(rest, pos + 1, acc + string_codepoint_size(codepoint))
  end

  defp string_chunk_size(other, pos, _acc), do: syntax_error(other, pos)

  defp string_codepoint_size(codepoint) when codepoint < 0x800, do: 2
  defp string_codepoint_size(codepoint) when codepoint < 0x10000, do: 3
  defp string_codepoint_size(_), do: 4

  ## Whitespace

  defp skip_whitespace(<<char>> <> rest, pos) when char in '\s\n\t\r' do
    skip_whitespace(rest, pos + 1)
  end

  defp skip_whitespace(string, pos), do: {string, pos}

  # https://tools.ietf.org/html/rfc7159#section-8.1
  # https://en.wikipedia.org/wiki/Byte_order_mark#UTF-8
  defp skip_bom(<<0xEF, 0xBB, 0xBF>> <> rest) do
    rest
  end

  defp skip_bom(string) do
    string
  end

  ## Errors

  defp syntax_error(<<token::utf8>> <> _, pos) do
    raise %ParseError{pos: pos, value: <<token::utf8>>}
  end

  defp syntax_error(_, pos) do
    raise %ParseError{pos: pos, value: ""}
  end
end
