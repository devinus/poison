defmodule Poison.Encode do
  def encode(thing) do
    iolist_to_binary(encode_value(thing))
  end

  def encode_value(nil),   do: "null"
  def encode_value(true),  do: "true"
  def encode_value(false), do: "false"

  def encode_value(thing) when is_atom(thing) do
    [ ?", atom_to_binary(thing), ?" ]
  end

  def encode_value(thing) when is_binary(thing) do
    [ ?", thing, ?" ]
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
    [ ?[, join((lc x inlist thing, do: encode_value(x)), ?,), ?] ]
  end

  def encode_value(thing) do
    encode_value(Poison.Encoder.encode(thing))
  end

  defp encode_object(key, value, acc) do
    [[encode_value(key), ?:, encode_value(value)] | acc]
  end

  defp join([], _joiner), do: []

  defp join(collection, joiner) do
    join(collection, joiner, [])
  end

  defp join([head], _joiner, acc) do
    :lists.reverse [head | acc]
  end

  defp join([head | rest], joiner, acc) do
    join(rest, joiner, [joiner, head | acc])
  end
end

defprotocol Poison.Encoder do
  def encode(value)
end
