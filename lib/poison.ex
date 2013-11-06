defmodule Poison do
  @whitespace ' \n\t\r'

  def parse(string) when is_binary(string) do
    value(string) |> elem(0)
  end

  lc ws inlist @whitespace do
    defp value(<< unquote(ws), rest :: binary >>), do: value(rest)
  end

  defp value("\"" <> rest), do: enter_string(rest)
  defp value("{"  <> rest), do: enter_object(rest)

  defp enter_string(rest) do
    { iolist, rest } = parse_string(rest, "")
    { iolist_to_binary(iolist), rest }
  end

  defp parse_string("\"" <> rest, acc) do
    { acc, rest }
  end

  defp parse_string(<< char :: utf8, rest :: binary >>, acc) do
    parse_string(rest, [acc, char])
  end

  defp enter_object(rest) do
    pairs(rest, [])
  end

  lc ws inlist @whitespace do
    defp pairs(<< unquote(ws), rest :: binary >>, acc), do: pairs(rest, acc)
  end

  defp pairs("\"" <> rest, acc) do
    { name, rest } = enter_string(rest)
    { value, rest } = pair_value(rest)
    pairs(rest, [ { name, value } | acc])
  end

  defp pairs("," <> rest, acc) do
    pairs(rest, acc)
  end

  defp pairs("}" <> rest, acc) do
    { :lists.reverse(acc), rest }
  end

  lc ws inlist @whitespace do
    defp pair_value(<< unquote(ws), rest :: binary >>), do: pair_value(rest)
  end

  defp pair_value(":" <> rest) do
    value(rest)
  end
end
