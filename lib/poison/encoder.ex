defmodule Poison.EncodeError do
  defexception value: nil, message: nil

  def message(%{value: value, message: nil}) do
    "unable to encode value: #{inspect value}"
  end

  def message(%{message: message}) do
    message
  end
end

defprotocol Poison.Encoder do
  @fallback_to_any true

  def encode(value, options)
end

defimpl Poison.Encoder, for: Atom do
  def encode(nil, _),   do: "null"
  def encode(true, _),  do: "true"
  def encode(false, _), do: "false"

  def encode(atom, options) do
    Poison.Encoder.BitString.encode(Atom.to_string(atom), options)
  end
end

defimpl Poison.Encoder, for: BitString do
  def encode("", _), do: "\"\""

  def encode(string, _options) do
    [?", escape(string), ?"]
  end

  defp escape(""), do: []

  for {char, seq} <- Enum.zip('"\n\t\r\\/\f\b', '"ntr\\/fb') do
    defp escape(<<unquote(char), rest :: binary>>) do
      [unquote("\\" <> <<seq>>) | escape(rest)]
    end
  end

  defp escape(string) do
    size = chunk_size(string, 0)
    <<chunk :: binary-size(size), rest :: binary>> = string
    [chunk | escape(rest)]
  end

  defp chunk_size(<<char, _rest :: binary>>, acc) when char in '"\n\t\r\\/\f\b' do
    acc
  end

  defp chunk_size(<<char, rest :: binary>>, acc) when char < 0x80 do
    chunk_size(rest, acc + 1)
  end

  defp chunk_size(<<codepoint :: utf8, rest :: binary>>, acc) do
    chunk_size(rest, acc + byte_size(codepoint))
  end

  defp chunk_size(_, acc), do: acc
end

defimpl Poison.Encoder, for: Integer do
  def encode(integer, _options) do
    Integer.to_string(integer)
  end
end

defimpl Poison.Encoder, for: Float do
  def encode(float, _options) do
    :io_lib_format.fwrite_g(float)
  end
end

defimpl Poison.Encoder, for: Map do
  alias Poison.Encoder
  alias Poison.EncodeError

  def encode(map, _) when map_size(map) < 1, do: "{}"

  def encode(map, options) do
    fun = &[?,, encode_name(&1, options), ?:, Encoder.encode(&2, options) | &3]
    [?{, tl(:maps.fold(fun, [], map)), ?}]
  end

  defp encode_name(name, options) do
    cond do
      is_binary(name) ->
        Encoder.BitString.encode(name, options)
      is_atom(name) ->
        Encoder.Atom.encode(name, options)
      true ->
        raise EncodeError, value: name,
          message: "keys must be atoms or strings, got: #{inspect name}"
    end
  end
end

defimpl Poison.Encoder, for: List do
  alias Poison.Encoder

  def encode([], _), do: "[]"

  def encode([head], options) do
    [?[, Encoder.encode(head, options), ?]]
  end

  def encode([head | rest], options) do
    tail = for value <- rest, do: [?,, Encoder.encode(value, options)]
    [?[, Encoder.encode(head, options), tail, ?]]
  end
end

defimpl Poison.Encoder, for: [Range, Stream] do
  def encode(stream, options) do
    Poison.Encoder.List.encode(Enum.to_list(stream), options)
  end
end

defimpl Poison.Encoder, for: Any do
  def encode(%{__struct__: _} = struct, options) do
    Poison.Encoder.Map.encode(Map.delete(struct, :__struct__), options)
  end

  def encode(value, _options) do
    raise Poison.EncodeError, value: value
  end
end
