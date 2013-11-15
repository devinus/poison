defmodule Poison do
  @moduledoc """
  A JSON parser modelled after ECMA 404.

  See: http://www.ecma-international.org/publications/files/ECMA-ST/ECMA-404.pdf
  """

  @compile :native

  defexception SyntaxError, message: "Unexpected input"

  @type t :: float | integer | String.t | Keyword.t

  @spec parse(String.t) :: { :ok, t } | { :error, :invalid }
  def parse(string) when is_binary(string) do
    { value, rest } = value(skip_whitespace(string))
    if rest != "" and skip_whitespace(rest) != "", do: throw(:invalid)
    { :ok, value }
  catch :invalid ->
    { :error, :invalid }
  end

  @spec parse(String.t) :: t
  def parse!(string) do
    case parse(string) do
      { :ok, value } -> value
      { :error, :invalid } -> raise SyntaxError
    end
  end

  defp value("\"" <> rest),    do: string_start(rest)
  defp value("{" <> rest),     do: object_start(rest)
  defp value("[" <> rest),     do: array_start(rest)
  defp value("null" <> rest),  do: { nil, rest }
  defp value("true" <> rest),  do: { true, rest }
  defp value("false" <> rest), do: { false, rest }

  lc char inlist '-0123456789' do
    defp value(<< unquote(char), _ :: binary >> = string) do
      number_start(string)
    end
  end

  defp value(_), do: throw(:invalid)

  # Objects

  defp object_start(string) do
    object_pairs(skip_whitespace(string), [])
  end

  defp object_pairs("\"" <> rest, acc) do
    { name, rest } = string_start(rest)
    { value, rest } = object_pair_value(skip_whitespace(rest))
    object_maybe_leave(skip_whitespace(rest), [ { name, value } | acc ])
  end

  defp object_pairs("}" <> rest, []) do
    { [], rest }
  end

  defp object_pairs(_, _), do: throw(:invalid)

  defp object_pair_value(":" <> rest) do
    value(skip_whitespace(rest))
  end

  defp object_pair_value(_), do: throw(:invalid)

  defp object_maybe_leave("," <> rest, acc) do
    object_pairs(skip_whitespace(rest), acc)
  end

  defp object_maybe_leave("}" <> rest, acc) do
    { :lists.reverse(acc), rest }
  end

  defp object_maybe_leave(_, _), do: throw(:invalid)

  # Arrays

  defp array_start(string) do
    array_values(skip_whitespace(string), [])
  end

  defp array_values("]" <> rest, _) do
    { [], rest }
  end

  defp array_values(string, acc) do
    { value, rest } = value(string)
    array_maybe_leave(skip_whitespace(rest), [ value | acc ])
  end

  defp array_maybe_leave("," <> rest, acc) do
    array_values(skip_whitespace(rest), acc)
  end

  defp array_maybe_leave("]" <> rest, acc) do
    { :lists.reverse(acc), rest }
  end

  defp array_maybe_leave(_, _), do: throw(:invalid)

  # Numbers

  defp number_start("-" <> rest) do
    { number, rest } = number_start(rest)
    { -number, rest }
  end

  defp number_start("0" <> rest) do
    number_frac(rest, [?0])
  end

  defp number_start(string) do
    number_int(string, [])
  end

  lc char inlist '123456789' do
    defp number_int(<< unquote(char), _ :: binary >> = string, acc) do
      { digits, rest } = number_digits(string)
      number_frac(rest, [acc, digits])
    end
  end

  defp number_int(_, _), do: throw(:invalid)

  defp number_frac("." <> rest, acc) do
    { digits, rest } = number_digits(rest)
    number_exp(rest, true, [acc, ?., digits])
  end

  defp number_frac(string, acc) do
    number_exp(string, false, acc)
  end

  defp number_exp(<< e, rest :: binary >>, true, acc) when e in 'eE' do
    number_exp_continue(rest, true, [acc, ?e])
  end

  defp number_exp(<< e, rest :: binary >>, false, acc) when e in 'eE' do
    number_exp_continue(rest, true, [acc, ".0e"])
  end

  defp number_exp(string, frac, acc) do
    { number_complete(acc, frac), string }
  end

  defp number_exp_continue("-" <> rest, _frac, acc) do
    { digits, rest } = number_digits(rest)
    { number_complete([acc, ?-, digits], true), rest }
  end

  defp number_exp_continue("+" <> rest, frac, acc) do
    { digits, rest } = number_digits(rest)
    { number_complete([acc, digits], true), rest }
  end

  defp number_exp_continue(string, frac, acc) do
    { digits, rest } = number_digits(string)
    { number_complete([acc, digits], frac), rest }
  end

  defp number_complete(iolist, false) do
    binary_to_integer(iolist_to_binary(iolist))
  end

  defp number_complete(iolist, true) do
    binary_to_float(iolist_to_binary(iolist))
  end

  defp number_digits(string) do
    count = number_digits_count(string, 0)
    << digits :: [ binary, size(count) ], rest :: binary >> = string
    { digits, rest }
  end

  lc char inlist '0123456789' do
    defp number_digits_count(<< unquote(char), rest :: binary >>, acc) do
      number_digits_count(rest, acc + 1)
    end
  end

  defp number_digits_count(_, 0),   do: throw(:invalid)
  defp number_digits_count(_, acc), do: acc

  # Strings

  defp string_start(string) do
    { iolist, rest } = string_continue(string, [])
    { iolist_to_binary(iolist), rest }
  end

  defp string_continue("\"" <> rest, acc) do
    { acc, rest }
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
  defp string_escape(<< ?u, a1, b1, c1, d1, "\\u", a2, b2, c2, d2, rest :: binary >>, acc)
      when a1 in [?d, ?D] and a2 in [?d, ?D] do
    hi = list_to_integer([ a1, b1, c1, d1 ], 16)
    lo = list_to_integer([ a2, b2, c2, d2 ], 16)
    codepoint = 0x10000 + ((hi - 0xD800) * 0x400) + (lo - 0xDC00);
    string_continue(rest, [ acc, << codepoint :: utf8 >> ])
  end

  defp string_escape(<< ?u, seq :: [ binary, size(4) ], rest :: binary >>, acc) do
    string_continue(rest, [ acc, << binary_to_integer(seq, 16) :: utf8 >> ])
  end

  defp string_escape(_, _), do: throw(:invalid)

  defp string_chunk_size("\"" <> _, acc), do: acc
  defp string_chunk_size("\\" <> _, acc), do: acc

  defp string_chunk_size(<< char, rest :: binary >>, acc) when char < 0x80 do
    string_chunk_size(rest, acc + 1)
  end

  defp string_chunk_size(<< codepoint :: utf8, rest :: binary >>, acc) do
    string_chunk_size(rest, acc + string_codepoint_size(codepoint))
  end

  defp string_chunk_size(_, acc), do: acc

  defp string_codepoint_size(codepoint) when codepoint < 0x8000,  do: 2
  defp string_codepoint_size(codepoint) when codepoint < 0x10000, do: 3
  defp string_codepoint_size(_),                                  do: 4

  # Whitespace

  # defp skip_whitespace(""), do: ""

  defp skip_whitespace("    " <> rest) do
    skip_whitespace(rest)
  end

  lc ws inlist '\s\n\t\r' do
    defp skip_whitespace(<< unquote(ws), rest :: binary >>) do
      skip_whitespace(rest)
    end
  end

  defp skip_whitespace(string) do
    string
  end
end
