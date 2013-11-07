defmodule Poison do
  def parse(string) when is_binary(string) do
    { value, rest } = value(skip_whitespace(string))
    if rest != "" or skip_whitespace(rest) != "", do: throw(:invalid)
    value
  end

  defp value("\"" <> rest),    do: string_start(rest)
  defp value("{" <> rest),     do: object_start(rest)
  defp value("[" <> rest),     do: array_start(rest)
  defp value("null" <> rest),  do: { nil, rest }
  defp value("true" <> rest),  do: { true, rest }
  defp value("false" <> rest), do: { false, rest }

  lc char inlist '-0123456789' do
    defp value(<< unquote(char), rest :: binary >>) do
      start_number(rest, unquote(char))
    end
  end

  defp value(_), do: throw(:invalid)

  ## Numbers

  defp start_number(<< ?0, _ :: binary >>, ?-) do
    throw(:invalid)
  end

  lc char inlist '0123456789' do
    defp start_number(<< unquote(char), _rest :: binary >>, ?0) do
      throw(:invalid)
    end

    defp start_number(<< unquote(char), rest :: binary >>, first) do
      number_int(rest, << first, unquote(char) >>)
    end
  end

  defp start_number("", ?-), do: throw(:invalid)

  defp start_number("", first) do
    { first - ?0, "" }
  end

  lc char inlist '0123456789' do
    defp number_int(<< unquote(char), rest :: binary >>, acc) do
      number_int(rest, << acc :: binary, unquote(char) >>)
    end
  end

  defp number_int(<< e, rest :: binary >>, acc) when e in 'eE' do
    { exp, rest } = number_exp(rest, "")
    { trunc(binary_to_float(<< acc :: binary, ".0e", exp :: binary >>)), rest }
  end

  defp number_int(<< ?., rest :: binary >>, acc) do
    { frac, exp, rest } = number_frac(rest, "")
    number = binary_to_float(<< acc :: binary, ?., frac :: binary, ?e, exp :: binary >>)
    { number, rest }
  end

  defp number_int(rest, acc) do
    { binary_to_integer(acc), rest }
  end

  lc char inlist '0123456789' do
    defp number_frac(<< unquote(char), rest :: binary >>, acc) do
      number_frac(rest, << acc :: binary, unquote(char) >>)
    end
  end

  defp number_frac(<< e, rest :: binary >>, acc) when e in 'eE' do
    { exp, rest } = number_exp(rest, "")
    { acc, exp, rest }
  end

  defp number_frac(rest, acc) do
    { acc, "0", rest }
  end

  lc char inlist '-0123456789' do
    defp number_exp(<< unquote(char), rest :: binary >>, acc) do
      number_exp(rest, << acc :: binary, unquote(char) >>)
    end
  end

  defp number_exp(rest, acc) do
    { acc, rest }
  end

  ## Strings

  defp string_start(string) do
    { iolist, rest } = parse_string(string, "")
    { iolist_to_binary(iolist), rest }
  end

  defp parse_string("\"" <> rest, acc) do
    { acc, rest }
  end

  defp parse_string(<< codepoint :: utf8, rest :: binary >>, acc) do
    parse_string(rest, [acc, codepoint])
  end

  ## Objects

  defp object_start(string) do
    object_pairs(skip_whitespace(string), [])
  end

  defp object_pairs("\"" <> rest, acc) do
    { name, rest } = string_start(rest)
    { value, rest } = object_pair_value(skip_whitespace(rest))
    maybe_leave_object(skip_whitespace(rest), [ { name, value } | acc ])
  end

  defp object_pairs(_, _), do: throw(:invalid)

  defp object_pair_value(":" <> rest) do
    value(skip_whitespace(rest))
  end

  defp object_pair_value(_), do: throw(:invalid)

  defp maybe_leave_object("," <> rest, acc) do
    object_pairs(skip_whitespace(rest), acc)
  end

  defp maybe_leave_object("}" <> rest, acc) do
    { :lists.reverse(acc), rest }
  end

  defp maybe_leave_object(_, _), do: throw(:invalid)

  ## Arrays

  defp array_start(string) do
    array_values(string, [])
  end

  defp array_values(string, acc) do
    { value, rest } = value(skip_whitespace(string))
    maybe_leave_array(rest, [ value | acc ])
  end

  defp maybe_leave_array("," <> rest, acc) do
    array_values(rest, acc)
  end

  defp maybe_leave_array("]" <> rest, acc) do
    { :lists.reverse(acc), rest }
  end

  defp maybe_leave_array(_, _), do: throw(:invalid)

  ## Whitespace

  defp skip_whitespace(""), do: ""

  lc ws inlist ' \n\t\r' do
    defp skip_whitespace(<< unquote(ws), rest :: binary >>) do
      skip_whitespace(rest)
    end
  end

  defp skip_whitespace(string) do
    string
  end
end
