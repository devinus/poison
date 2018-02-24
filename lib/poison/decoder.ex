defmodule Poison.DecodeError do
  @type t :: %__MODULE__{message: String.t, value: any}

  defexception message: nil, value: nil

  def message(%{message: nil, value: value}) do
    "unable to decode value: #{inspect(value)}"
  end

  def message(%{message: message}) do
    message
  end
end

defmodule Poison.Decode do
  @moduledoc false

  alias Poison.Decoder

  def transform(value, options) when is_map(value) or is_list(value) do
    case Map.get(options, :as) do
      nil -> value
      as -> transform(value, Map.get(options, :keys), as, options)
    end
  end

  def transform(value, _options) do
    value
  end

  defp transform(nil, _keys, _as, _options), do: nil

  defp transform(value, keys, %{__struct__: _} = as, options) do
    Decoder.Remap.remap( as, value, keys )
    |> transform_struct(keys, as, options)
  end

  defp transform(value, keys, as, options) when is_map(as) do
    transform_map(value, keys, as, options)
  end

  defp transform(value, keys, [as], options) do
    for v <- value, do: transform(v, keys, as, options)
  end

  defp transform(value, _keys, _as, _options) do
    value
  end

  defp transform_map(value, keys, as, options) do
    Enum.reduce(as, value, fn {key, as}, acc ->
      case Map.get(acc, key) do
        value when is_map(value) or is_list(value) ->
          Map.put(acc, key, transform(value, keys, as, options))
        _ ->
          acc
      end
    end)
  end

  defp transform_struct(value, keys, as, options) when keys in [:atoms, :atoms!] do
    as
    |> Map.from_struct
    |> Map.merge(value)
    |> do_transform_struct(keys, as, options)
  end

  defp transform_struct(value, keys, as, options) do
    as
    |> Map.from_struct
    |> Enum.reduce(%{}, fn {key, default}, acc ->
      Map.put(acc, key, Map.get(value, Atom.to_string(key), default))
    end)
    |> do_transform_struct(keys, as, options)
  end

  defp do_transform_struct(value, keys, as, options) do
    default = struct(as.__struct__)

    as
    |> Map.from_struct
    |> Enum.reduce(%{}, fn {key, as}, acc ->
      new_value = case Map.fetch(value, key) do
        {:ok, ^as} when is_map(as) or is_list(as) ->
          Map.get(default, key)
        {:ok, value} when is_map(value) or is_list(value) ->
          transform(value, keys, as, options)
        {:ok, value} ->
          value
        :error ->
          Map.get(default, key)
      end

      Map.put(acc, key, new_value)
    end)
    |> Map.put(:__struct__, as.__struct__)
    |> Decoder.decode(options)
  end
end

defprotocol Poison.Decoder do
  @fallback_to_any true

  @typep keys :: :atoms | :atoms!
  @typep as :: map | struct | [as]

  @type options :: %{
    optional(:keys) => keys,
    optional(:as) => as,
  }

  @spec decode(t, options) :: any
  def decode(value, options)
end

defimpl Poison.Decoder, for: Any do
  def decode(value, _options) do
    value
  end
end

defprotocol Poison.Decoder.Remap do
  @moduledoc """
  Hook via protocol for adjusting keys or the value map in general
  when decoding to a struct. remap gets called after parsing but before
  decoding to an `as` target. Base use case is translating camelCase
  keys to under_score.

  ```
  defimpl Poison.Decoder.Remap, for: Contact2 do
    def remap( _as, contact, keys ) when keys in [ :atoms, :atoms! ], do: contact
    def remap( _as, contact, _keys ) do
      Map.new( contact, fn { k, v } -> { Macro.underscore( k ), v } end )
    end
  end
  ```
  """

  @fallback_to_any true
  @type keys :: :atoms | :atoms!
  @spec remap( as :: struct, value :: map, keys :: keys ) :: map
  def remap( as, value, keys )
end

defimpl Poison.Decoder.Remap, for: Any do
  def remap( _as, value, _keys ), do: value
end
