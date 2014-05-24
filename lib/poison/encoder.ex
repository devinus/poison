defprotocol Poison.Encoder do
  def encode(value)
end

defimpl Poison.Encoder, for: Atom do
  def encode(nil),   do: "null"
  def encode(true),  do: "true"
  def encode(false), do: "false"

  def encode(atom) do
    Poison.Encoder.encode(atom_to_binary(atom))
  end
end

defimpl Poison.Encoder, for: BitString do
  def encode(""), do: "\"\""

  def encode(string) do
    [ ?", escape(string, []), ?" ]
  end

  defp escape("", acc) do
    acc
  end

  for { char, seq } <- Enum.zip('"\n\t\r\\/\f\b', '"ntr\\/fb') do
    defp escape(<< unquote(char), rest :: binary >>, acc) do
      escape(rest, [ acc, ?\\, unquote(seq) ])
    end
  end

  defp escape(string, acc) do
    size = chunk_size(string, 0)
    << chunk :: [ binary, size(size) ], rest :: binary >> = string
    escape(rest, [ acc, chunk ])
  end

  defp chunk_size(<< char, _rest :: binary >>, acc) when char in '"\n\t\r\\/\f\b' do
    acc
  end

  defp chunk_size(<< char, rest :: binary >>, acc) when char < 0x80 do
    chunk_size(rest, acc + 1)
  end

  defp chunk_size(<< codepoint :: utf8, rest :: binary >>, acc) do
    chunk_size(rest, acc + byte_size(codepoint))
  end

  defp chunk_size(_, acc), do: acc
end

defimpl Poison.Encoder, for: Integer do
  def encode(integer) do
    integer_to_binary(integer)
  end
end

defimpl Poison.Encoder, for: Float do
  def encode(float) do
    :io_lib_format.fwrite_g(float)
  end
end

defimpl Poison.Encoder, for: Map do
  alias Poison.Encoder

  def encode(map) when map_size(map) < 1, do: "{}"

  def encode(map) do
    [ ?{, tl(:maps.fold(&encode_pair/3, [], map)), ?} ]
  end

  defp encode_pair(name, value, acc) do
    [?,, encode_name(name), ?:, Encoder.encode(value) | acc]
  end

  defp encode_name(name) when is_binary(name) do
    Encoder.encode(name)
  end

  defp encode_name(name) do
    Encoder.encode(to_string(name))
  end
end

defimpl Poison.Encoder, for: List do
  alias Poison.Encoder

  def encode([]), do: "[]"

  def encode([head]) do
    [ ?[, Encoder.encode(head), ?] ]
  end

  def encode([head | rest]) do
    [ ?[, Encoder.encode(head), (for v <- rest, do: [?,, Encoder.encode(v)]), ?] ]
  end
end

defimpl Poison.Encoder, for: [Range, Stream.Lazy] do
  def encode(stream) do
    Poison.Encoder.encode(Enum.to_list(stream))
  end
end

defmodule Poison do
  def encode(value) do
    Poison.Encoder.encode(value)
  end
end
