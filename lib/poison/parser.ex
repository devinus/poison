defexception Poison.SyntaxError, token: nil do
  def message(__MODULE__[token: nil]) do
    "Unexpected end of input"
  end

  def message(__MODULE__[token: token]) do
    "Unexpected token: #{token}"
  end
end

defmodule Poison.Parser do
  @moduledoc """
  An ECMA 404 conforming JSON parser.

  See: http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
  """

  @compile :native

  @type t :: float | integer | String.t | Keyword.t

  @spec parse(String.t) :: { :ok, t } | { :error, :invalid }
    | { :error, :invalid, String.t }
  def parse(string) when is_binary(string) do
    { value, rest } = value(skip_whitespace(string))
    case skip_whitespace(rest) do
      "" -> { :ok, value }
      other -> syntax_error(other)
    end
  catch
    :invalid ->
      { :error, :invalid }
    { :invalid, token } ->
      { :error, :invalid, token }
  end

  @spec parse(String.t) :: t
  def parse!(string) do
    case parse(string) do
      { :ok, value } ->
        value
      { :error, :invalid } ->
        raise SyntaxError
      { :error, :invalid, token } ->
        raise SyntaxError, token: token
    end
  end

  defp value("\"" <> rest),    do: string_continue(rest, [])
  defp value("{" <> rest),     do: object_pairs(skip_whitespace(rest), [])
  defp value("[" <> rest),     do: array_values(skip_whitespace(rest), [])
  defp value("null" <> rest),  do: { nil, rest }
  defp value("true" <> rest),  do: { true, rest }
  defp value("false" <> rest), do: { false, rest }

  defp value(<< char, _ :: binary >> = string) when char in '-0123456789' do
    number_start(string)
  end

  defp value(other), do: syntax_error(other)

  ## Objects

  defp object_pairs("\"" <> rest, acc) do
    { name, rest } = string_continue(rest, [])
    { value, rest } = case skip_whitespace(rest) do
      ":" <> rest -> value(skip_whitespace(rest))
      other -> syntax_error(other)
    end

    acc = [ { name, value } | acc ]
    case skip_whitespace(rest) do
      "," <> rest -> object_pairs(skip_whitespace(rest), acc)
      "}" <> rest -> { :maps.from_list(acc), rest }
      other -> syntax_error(other)
    end
  end

  defp object_pairs("}" <> rest, []) do
    { :maps.new, rest }
  end

  defp object_pairs(other, _), do: syntax_error(other)

  ## Arrays

  defp array_values("]" <> rest, _) do
    { [], rest }
  end

  defp array_values(string, acc) do
    { value, rest } = value(string)

    acc = [ value | acc ]
    case skip_whitespace(rest) do
      "," <> rest -> array_values(skip_whitespace(rest), acc)
      "]" <> rest -> { :lists.reverse(acc), rest }
      other -> syntax_error(other)
    end
  end

  ## Numbers

  defp number_start("-" <> rest) do
    case rest do
      "0" <> rest -> number_frac(rest, ["-0"])
      rest -> number_int(rest, [?-])
    end
  end

  defp number_start("0" <> rest) do
    number_frac(rest, [?0])
  end

  defp number_start(string) do
    number_int(string, [])
  end

  defp number_int(<< char, _ :: binary >> = string, acc) when char in '123456789' do
    { first, digits, rest } = number_digits(string)
    number_frac(rest, [acc, first, digits])
  end

  defp number_int(other, _), do: syntax_error(other)

  defp number_frac("." <> rest, acc) do
    { first, digits, rest } = number_digits(rest)
    number_exp(rest, true, [acc, ?., first, digits])
  end

  defp number_frac(string, acc) do
    number_exp(string, false, acc)
  end

  defp number_exp(<< e, rest :: binary >>, frac, acc) when e in 'eE' do
    e = if frac, do: ?e, else: ".0e"
    number_exp_continue(rest, acc, e)
  end

  defp number_exp(string, frac, acc) do
    { number_complete(acc, frac), string }
  end

  defp number_exp_continue("-" <> rest, acc, e) do
    { first, digits, rest } = number_digits(rest)
    { number_complete([acc, e, ?-, first, digits], true), rest }
  end

  defp number_exp_continue("+" <> rest, acc, e) do
    { first, digits, rest } = number_digits(rest)
    { number_complete([acc, e, first, digits], true), rest }
  end

  defp number_exp_continue(rest, acc, e) do
    { first, digits, rest } = number_digits(rest)
    { number_complete([acc, e, first, digits], true), rest }
  end

  defp number_complete(iolist, false) do
    binary_to_integer(iolist_to_binary(iolist))
  end

  defp number_complete(iolist, true) do
    binary_to_float(iolist_to_binary(iolist))
  end

  defp number_digits(<< char, rest :: binary >>) when char in '0123456789' do
    count = number_digits_count(rest, 0)
    << digits :: [ binary, size(count) ], rest :: binary >> = rest
    { char, digits, rest }
  end

  defp number_digits(other), do: syntax_error(other)

  defp number_digits_count(<< char, rest :: binary >>, acc) when char in '0123456789' do
    number_digits_count(rest, acc + 1)
  end

  defp number_digits_count(_, acc), do: acc

  ## Strings

  defp string_continue("\"" <> rest, acc) do
    { iolist_to_binary(acc), rest }
  end

  defp string_continue("\\" <> rest, acc) do
    string_escape(rest, acc)
  end

  defp string_continue("", _), do: throw(:invalid)

  defp string_continue(string, acc) do
    n = string_chunk_size(string, 0)
    << chunk :: [ binary, size(n) ], rest :: binary >> = string
    string_continue(rest, [ acc, chunk ])
  end

  lc { seq, char } inlist Enum.zip('"ntr\\/fb', '"\n\t\r\\/\f\b') do
    defp string_escape(<< unquote(seq), rest :: binary >>, acc) do
      string_continue(rest, [ acc, unquote(char) ])
    end
  end

  # http://www.ietf.org/rfc/rfc2781.txt
  # http://perldoc.perl.org/Encode/Unicode.html#Surrogate-Pairs
  # http://mathiasbynens.be/notes/javascript-encoding#surrogate-pairs
  defp string_escape(<< ?u, a1, b1, c1, d1, "\\u", a2, b2, c2, d2, rest :: binary >>, acc)
    when a1 in [?d, ?D] and a2 in [?d, ?D]
    and (b1 in [?8, ?9, ?a, ?b, ?A, ?B])
    and (b2 in ?c..?f or b2 in ?C..?F) \
  do
    hi = list_to_integer([ a1, b1, c1, d1 ], 16)
    lo = list_to_integer([ a2, b2, c2, d2 ], 16)
    codepoint = 0x10000 + ((hi - 0xD800) * 0x400) + (lo - 0xDC00)
    string_continue(rest, [ acc, << codepoint :: utf8 >> ])
  end

  defp string_escape(<< ?u, seq :: [ binary, size(4) ], rest :: binary >>, acc) do
    string_continue(rest, [ acc, << binary_to_integer(seq, 16) :: utf8 >> ])
  end

  defp string_escape(other, _), do: syntax_error(other)

  defp string_chunk_size("\"" <> _, acc), do: acc
  defp string_chunk_size("\\" <> _, acc), do: acc

  defp string_chunk_size(<< char, rest :: binary >>, acc) when char < 0x80 do
    string_chunk_size(rest, acc + 1)
  end

  defp string_chunk_size(<< codepoint :: utf8, rest :: binary >>, acc) do
    string_chunk_size(rest, acc + string_codepoint_size(codepoint))
  end

  defp string_chunk_size(_, acc), do: acc

  defp string_codepoint_size(codepoint) when codepoint < 0x800,   do: 2
  defp string_codepoint_size(codepoint) when codepoint < 0x10000, do: 3
  defp string_codepoint_size(_),                                  do: 4

  ## Whitespace

  defp skip_whitespace("    " <> rest), do: skip_whitespace(rest)

  defp skip_whitespace(<< char, rest :: binary >>) when char in '\s\n\t\r' do
    skip_whitespace(rest)
  end

  defp skip_whitespace(string), do: string

  ## Errors

  defp syntax_error(<< token :: utf8, _ :: binary >>) do
    throw({ :invalid, << token >> })
  end

  defp syntax_error(_) do
    throw(:invalid)
  end
end
