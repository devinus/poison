defmodule Poison.Decode do
  def decode(value, options) do
    as = options[:as]
    case is_map(value) do
      true when is_map(as) ->
        transform_map(value, options[:keys], as, options)
      true when is_atom(as) and not nil?(as) ->
        transform_struct(value, options[:keys], as, options)
      _ -> value
    end
  end

  defp transform_map(value, keys, as, options) do
    Enum.reduce(as, value, fn
      ({ key, as }, acc) when is_map(as) ->
        case Map.get(acc, key) do
          nil -> acc
          value -> Map.put(acc, key, transform_map(value, keys, as, options))
        end
      ({ key, as }, acc) when is_atom(as) ->
        case Map.get(acc, key) do
          nil -> acc
          value -> Map.put(acc, key, transform_struct(value, keys, as, options))
        end
    end)
  end

  defp transform_struct(value, keys, as, options) when keys in [:atoms, :atoms!] do
    Poison.Decoder.decode(struct(as, value), options)
  end

  defp transform_struct(value, _keys, as, options) do
    map = for { k, v } <- value, do: { binary_to_existing_atom(k), v }
    Poison.Decoder.decode(struct(as, map), options)
  end
end

defprotocol Poison.Decoder do
  @fallback_to_any true

  def decode(value, options)
end

defimpl Poison.Decoder, for: Any do
  def decode(%{__struct__: _} = value, _options) do
    value
  end

  def decode(value, _options) do
    raise(Protocol.UndefinedError, protocol: @protocol, value: value)
  end
end
