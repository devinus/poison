defmodule Poison.EncodeError do
  @type t :: %__MODULE__{message: String.t(), value: any}

  defexception message: nil, value: nil

  def message(%{message: nil, value: value}) do
    "unable to encode value: #{inspect(value)}"
  end

  def message(%{message: message}) do
    message
  end
end

defmodule Poison.Encode do
  @moduledoc false

  alias Poison.{EncodeError, Encoder}

  defmacro __using__(_) do
    quote do
      alias Poison.EncodeError
      alias String.Chars

      @compile {:inline, encode_name: 1}

      # Fast path encoding string keys
      defp encode_name(value) when is_binary(value) do
        value
      end

      defp encode_name(value) do
        case Chars.impl_for(value) do
          nil ->
            raise EncodeError,
              value: value,
              message:
                "expected a String.Chars encodable value, got: #{inspect(value)}"

          impl ->
            impl.to_string(value)
        end
      end
    end
  end
end

defmodule Poison.Pretty do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      @default_indent 2
      @default_offset 0

      @compile {:inline, pretty: 1, indent: 1, offset: 1, offset: 2, spaces: 1}

      defp pretty(options) do
        Map.get(options, :pretty) == true
      end

      defp indent(options) do
        Map.get(options, :indent, @default_indent)
      end

      defp offset(options) do
        Map.get(options, :offset, @default_offset)
      end

      defp offset(options, value) do
        Map.put(options, :offset, value)
      end

      defp spaces(count) do
        :binary.copy(" ", count)
      end
    end
  end
end

defprotocol Poison.Encoder do
  @fallback_to_any true

  @typep escape :: :unicode | :javascript | :html_safe
  @typep pretty :: boolean
  @typep indent :: non_neg_integer
  @typep offset :: non_neg_integer
  @typep strict_keys :: boolean

  @type options :: %{
          optional(:escape) => escape,
          optional(:pretty) => pretty,
          optional(:indent) => indent,
          optional(:offset) => offset,
          optional(:strict_keys) => strict_keys
        }

  @spec encode(t, options) :: iodata
  def encode(value, options)
end

defimpl Poison.Encoder, for: Atom do
  alias Poison.Encoder

  def encode(nil, _), do: "null"
  def encode(true, _), do: "true"
  def encode(false, _), do: "false"

  def encode(atom, options) do
    Encoder.BitString.encode(Atom.to_string(atom), options)
  end
end

defimpl Poison.Encoder, for: BitString do
  alias Poison.EncodeError

  use Bitwise

  def encode("", _), do: "\"\""

  def encode(string, options) do
    [?", escape(string, Map.get(options, :escape)), ?"]
  end

  defp escape("", _), do: []

  for {char, seq} <- Enum.zip('"\\\n\t\r\f\b', '"\\ntrfb') do
    defp escape(<<unquote(char)>> <> rest, mode) do
      [unquote("\\" <> <<seq>>) | escape(rest, mode)]
    end
  end

  # http://en.wikipedia.org/wiki/Unicode_control_characters
  defp escape(<<char>> <> rest, mode) when char <= 0x1F or char == 0x7F do
    [seq(char) | escape(rest, mode)]
  end

  defp escape(<<char::utf8>> <> rest, mode) when char in 0x80..0x9F do
    [seq(char) | escape(rest, mode)]
  end

  defp escape(<<char::utf8>> <> rest, :unicode) when char in 0xA0..0xFFFF do
    [seq(char) | escape(rest, :unicode)]
  end

  # http://en.wikipedia.org/wiki/UTF-16#Example_UTF-16_encoding_procedure
  # http://unicodebook.readthedocs.org/unicode_encodings.html
  defp escape(<<char::utf8>> <> rest, :unicode) when char > 0xFFFF do
    code = char - 0x10000

    [
      seq(0xD800 ||| code >>> 10),
      seq(0xDC00 ||| (code &&& 0x3FF))
      | escape(rest, :unicode)
    ]
  end

  defp escape(<<char::utf8>> <> rest, mode)
       when mode in [:html_safe, :javascript] and char in [0x2028, 0x2029] do
    [seq(char) | escape(rest, mode)]
  end

  defp escape(<<?/::utf8>> <> rest, :html_safe) do
    ["\\/" | escape(rest, :html_safe)]
  end

  defp escape(string, mode) do
    size = chunk_size(string, mode, 0)
    <<chunk::binary-size(size), rest::binary>> = string
    [chunk | escape(rest, mode)]
  end

  defp chunk_size(<<char>> <> _, _mode, acc)
       when char <= 0x1F or char in '"\\' do
    acc
  end

  defp chunk_size(<<?/::utf8>> <> _, :html_safe, acc) do
    acc
  end

  defp chunk_size(<<char>> <> rest, mode, acc) when char < 0x80 do
    chunk_size(rest, mode, acc + 1)
  end

  defp chunk_size(<<_::utf8>> <> _, :unicode, acc) do
    acc
  end

  defp chunk_size(<<char::utf8>> <> _, mode, acc)
       when mode in [:html_safe, :javascript] and char in [0x2028, 0x2029] do
    acc
  end

  defp chunk_size(<<codepoint::utf8>> <> rest, mode, acc) do
    size =
      cond do
        codepoint < 0x800 -> 2
        codepoint < 0x10000 -> 3
        true -> 4
      end

    chunk_size(rest, mode, acc + size)
  end

  defp chunk_size("", _, acc), do: acc

  defp chunk_size(other, _, _) do
    raise EncodeError, value: other
  end

  @compile {:inline, seq: 1}
  defp seq(char) do
    case Integer.to_charlist(char, 16) do
      s when length(s) < 2 -> ["\\u000" | s]
      s when length(s) < 3 -> ["\\u00" | s]
      s when length(s) < 4 -> ["\\u0" | s]
      s -> ["\\u" | s]
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
  @compile :inline_list_funcs

  alias Poison.{Encoder, EncodeError}

  use Poison.{Encode, Pretty}

  def encode(map, _) when map_size(map) < 1, do: "{}"

  def encode(map, options) do
    map
    |> strict_keys(Map.get(options, :strict_keys, false))
    |> encode(pretty(options), options)
  end

  def encode(map, true, options) do
    indent = indent(options)
    offset = offset(options) + indent
    options = offset(options, offset)

    fun =
      &[
        ",\n",
        spaces(offset),
        Encoder.BitString.encode(encode_name(&1), options),
        ": ",
        Encoder.encode(:maps.get(&1, map), options) | &2
      ]

    [
      "{\n",
      tl(:lists.foldl(fun, [], :maps.keys(map))),
      ?\n,
      spaces(offset - indent),
      ?}
    ]
  end

  def encode(map, _, options) do
    fun =
      &[
        ?,,
        Encoder.BitString.encode(encode_name(&1), options),
        ?:,
        Encoder.encode(:maps.get(&1, map), options) | &2
      ]

    [?{, tl(:lists.foldl(fun, [], :maps.keys(map))), ?}]
  end

  defp strict_keys(map, false), do: map

  defp strict_keys(map, true) do
    map
    |> Map.keys()
    |> Enum.each(fn key ->
      name = encode_name(key)

      if Map.has_key?(map, name) do
        raise EncodeError,
          value: name,
          message: "duplicate key found: #{inspect(key)}"
      end
    end)

    map
  end
end

defimpl Poison.Encoder, for: List do
  alias Poison.Encoder

  use Poison.Pretty

  @compile :inline_list_funcs

  def encode([], _), do: "[]"

  def encode(list, options) do
    encode(list, pretty(options), options)
  end

  def encode(list, false, options) do
    fun = &[?,, Encoder.encode(&1, options) | &2]
    [?[, tl(:lists.foldr(fun, [], list)), ?]]
  end

  def encode(list, true, options) do
    indent = indent(options)
    offset = offset(options) + indent
    options = offset(options, offset)

    fun = &[",\n", spaces(offset), Encoder.encode(&1, options) | &2]
    ["[\n", tl(:lists.foldr(fun, [], list)), ?\n, spaces(offset - indent), ?]]
  end
end

defimpl Poison.Encoder, for: [Range, Stream, MapSet, HashSet] do
  alias Poison.Encoder

  use Poison.Pretty

  def encode(collection, options) do
    encode(collection, pretty(options), options)
  end

  def encode(collection, false, options) do
    fun = &[?,, Encoder.encode(&1, options)]

    case Enum.flat_map(collection, fun) do
      [] -> "[]"
      [_ | tail] -> [?[, tail, ?]]
    end
  end

  def encode(collection, true, options) do
    indent = indent(options)
    offset = offset(options) + indent
    options = offset(options, offset)

    fun = &[",\n", spaces(offset), Encoder.encode(&1, options)]

    case Enum.flat_map(collection, fun) do
      [] -> "[]"
      [_ | tail] -> ["[\n", tail, ?\n, spaces(offset - indent), ?]]
    end
  end
end

defimpl Poison.Encoder, for: [Date, Time, NaiveDateTime, DateTime] do
  alias Poison.Encoder

  def encode(value, options) do
    Encoder.BitString.encode(@for.to_iso8601(value), options)
  end
end

defimpl Poison.Encoder, for: Any do
  alias Poison.{Encoder, EncodeError}

  defmacro __deriving__(module, struct, options) do
    deriving(module, struct, options)
  end

  def deriving(module, _struct, options) do
    only = options[:only]
    except = options[:except]

    extractor =
      cond do
        only ->
          quote(do: Map.take(struct, unquote(only)))

        except ->
          except = [:__struct__ | except]
          quote(do: Map.drop(struct, unquote(except)))

        true ->
          quote(do: :maps.remove(:__struct__, struct))
      end

    quote do
      defimpl Encoder, for: unquote(module) do
        def encode(struct, options) do
          Encoder.Map.encode(unquote(extractor), options)
        end
      end
    end
  end

  def encode(%{__struct__: _} = struct, options) do
    Encoder.Map.encode(Map.from_struct(struct), options)
  end

  def encode(value, _options) do
    raise EncodeError, value: value
  end
end
