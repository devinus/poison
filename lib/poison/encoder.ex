defmodule Poison.Encode do
  def encode(thing) do
    iolist_to_binary(encode_value(thing))
  end

  def encode_value([ { _key, _value } | _] = thing) do
    pairs = lc { key, value } inlist thing do
      [encode_value(key), ?:, encode_value(value)]
    end

    [ ?{, join(pairs, ?,), ?} ]
  end

  def encode_value(thing) when is_list(thing) do
    IO.inspect join(thing, ?,)
    [ ?[, join((lc x inlist thing, do: encode_value(x)), ?,), ?] ]
  end

  def encode_value(nil),   do: "nil"
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
    iolist_to_binary(:io_lib_format.fwrite_g(thing))
  end

  defp join([], _joiner), do: []

  defp join(collection, joiner) do
    join(collection, joiner, [])
  end

  defp join([head], _joiner, acc) do
    :lists.reverse [head | acc]
  end

  defp join([head | rest], joiner, acc) do
    join(rest, joiner, [head, joiner | acc])
  end
end
