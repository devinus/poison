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
  use Bitwise

  def encode("", _), do: "\"\""

  def encode(string, options) do
    [?", escape(string, options[:escape]), ?"]
  end

  defp escape("", _), do: []

  for {char, seq} <- Enum.zip('"\\\n\t\r\f\b', '"\\ntrfb') do
    defp escape(<<unquote(char)>> <> rest, mode) do
      [unquote("\\" <> <<seq>>) | escape(rest, mode)]
    end
  end

  defp escape(<<char>> <> rest, mode) when char < 0x1F do
    [seq(char) | escape(rest, mode)]
  end

  defp escape(<<char :: utf8>> <> rest, :unicode) when char in 0x80..0xFFFF do
    [seq(char) | escape(rest, :unicode)]
  end

  # http://en.wikipedia.org/wiki/UTF-16#Example_UTF-16_encoding_procedure
  # http://unicodebook.readthedocs.org/unicode_encodings.html#utf-16-surrogate-pairs
  defp escape(<<char :: utf8>> <> rest, :unicode) when char > 0xFFFF do
    code = char - 0x10000
    [seq(0xD800 ||| (code >>> 10)),
     seq(0xDC00 ||| (code &&& 0x3FF))
     | escape(rest, :unicode)]
  end

  defp escape(<<char :: utf8>> <> rest, :javascript) when char in [0x2028, 0x2029] do
    [seq(char) | escape(rest, :javascript)]
  end

  defp escape(string, mode) do
    size = chunk_size(string, mode, 0)
    <<chunk :: binary-size(size), rest :: binary>> = string
    [chunk | escape(rest, mode)]
  end

  defp chunk_size(<<char>> <> _, _mode, acc) when char < 0x1F or char == ?\\ do
    acc
  end

  defp chunk_size(<<char>> <> rest, mode, acc) when char < 0x80 do
    chunk_size(rest, mode, acc + 1)
  end

  defp chunk_size(<<_ :: utf8>> <> _, :unicode, acc) do
    acc
  end

  defp chunk_size(<<char :: utf8>> <> _, :javascript, acc) when char in [0x2028, 0x2029] do
    acc
  end

  defp chunk_size(<<codepoint :: utf8>> <> rest, mode, acc) do
    chunk_size(rest, mode, acc + codepoint_size(codepoint))
  end

  defp chunk_size(_, _, acc), do: acc

  defp codepoint_size(codepoint) do
    cond do
      codepoint < 0x800   -> 2
      codepoint < 0x10000 -> 3
      true                -> 4
    end
  end

  defp seq(char) do
    case Integer.to_string(char, 16) do
      s when byte_size(s) < 2 -> ["\\u000", s]
      s when byte_size(s) < 3 -> ["\\u00", s]
      s when byte_size(s) < 4 -> ["\\u0", s]
      s -> ["\\u", s]
    end
  end
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

  def encode(map, _) when map_size(map) < 1, do: "{}"

  def encode(map, options) do
    fun = &[?,, Encoder.BitString.encode(to_string(&1), options), ?:,
                Encoder.encode(&2, options) | &3]
    [?{, tl(:maps.fold(fun, [], map)), ?}]
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

defimpl Poison.Encoder, for: [Range, Stream, HashSet] do
  def encode(collection, options) do
    list = Enum.flat_map(collection, &[?,, Poison.Encoder.encode(&1, options)])

    case list do
      [] -> "[]"
      [_ | tail] -> [?[, tail, ?]]
    end
  end
end

defimpl Poison.Encoder, for: HashDict do
  alias Poison.Encoder

  def encode(dict, options) do
    list = Enum.flat_map(dict, fn {key, value} ->
      [?,, Encoder.BitString.encode(to_string(key), options), ?:,
           Encoder.encode(value, options)]
    end)

    case list do
      [] -> "{}"
      [_ | tail] -> [?{, tail, ?}]
    end
  end
end

defimpl Poison.Encoder, for: Any do
  def encode(%{__struct__: _} = struct, options) do
    Poison.Encoder.Map.encode(Map.from_struct(struct), options)
  end

  def encode(value, _options) do
    raise Poison.EncodeError, value: value
  end
end
