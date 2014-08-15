defmodule Poison.Decode do
  def decode(value, options) when is_map(value) or is_list(value) do
    case options[:as] do
      nil -> value
      as -> transform(value, options[:keys], as, options)
    end
  end

  def decode(value, _options) do
    value
  end

  defp transform(value, keys, as, options) when is_map(as) do
    transform_map(value, keys, as, options)
  end

  defp transform(value, keys, as, options) when is_atom(as) do
    transform_struct(value, keys, as, options)
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
        nil -> acc
        value -> Map.put(acc, key, transform(value, keys, as, options))
      end
    end)
  end

  defp transform_struct(value, keys, as, options) when keys in [:atoms, :atoms!] do
    Poison.Decoder.decode(struct(as, value), options)
  end

  defp transform_struct(value, _keys, as, options) do
    kv = for k <- Map.keys(Map.from_struct(as.__struct__)) do
      {k, Map.get(value, Atom.to_string(k))}
    end

    Poison.Decoder.decode(struct(as, kv), options)
  end
end

defprotocol Poison.Decoder do
  @fallback_to_any true

  def decode(value, options)
end

defimpl Poison.Decoder, for: Any do
  def decode(value, _options) do
    value
  end
end
