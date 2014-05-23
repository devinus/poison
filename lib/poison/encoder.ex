defmodule Poison.Encode do
  def encode(thing) do
    iodata_to_binary(encode_value(thing))
  end

  def encode_value(nil),   do: "null"
  def encode_value(true),  do: "true"
  def encode_value(false), do: "false"

  def encode_value(thing) when is_atom(thing) do
    encode_string(atom_to_binary(thing))
  end

  def encode_value(thing) when is_binary(thing) do
    encode_string(thing)
  end

  def encode_value(thing) when is_integer(thing) do
    integer_to_binary(thing)
  end

  def encode_value(thing) when is_float(thing) do
    :io_lib_format.fwrite_g(thing)
  end

  def encode_value(thing) when is_map(thing) do
    [ ?{, join(:maps.fold(&encode_object/3, [], thing), ?,), ?} ]
  end

  def encode_value(thing) when is_list(thing) do
    [ ?[, join((for x <- thing, do: encode_value(x)), ?,), ?] ]
  end

  def encode_value(thing) do
    encode_value(Poison.Encoder.encode(thing))
  end

  defp encode_object(name, value, acc) do
    [[encode_string(name), ?:, encode_value(value)] | acc]
  end

  defp encode_string(string) when is_binary(string) do
    [ ?", string, ?" ]
  end

  defp join([], _joiner), do: []

  defp join([head], _joiner) do
    [head]
  end

  defp join([head | rest], joiner) do
    [head, joiner | join(rest, joiner)]
  end
end

defprotocol Poison.Encoder do
  def encode(value)
end
