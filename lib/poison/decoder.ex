defmodule Poison.Decoder do
  def decode(value, options) do
    as = options[:as]
    case is_map(value) do
      true when is_map(as) ->
        transform_map(value, options[:keys], as)
      true when is_atom(as) and as ->
        transform_struct(value, options[:keys], as)
      _ -> value
    end
  end

  defp transform_map(value, keys, as) do
    Enum.reduce(as, value, fn
      ({ key, as }, acc) when is_map(as) ->
        case Map.get(acc, key) do
          nil -> acc
          value -> Map.put(acc, key, transform_map(value, keys, as))
        end
      ({ key, as }, acc) when is_atom(as) ->
        case Map.get(acc, key) do
          nil -> acc
          value -> Map.put(acc, key, transform_struct(value, keys, as))
        end
    end)
  end

  defp transform_struct(value, keys, as) when keys in [:atoms, :atoms!] do
    struct(as, value)
  end

  defp transform_struct(value, _keys, as) do
    struct(as, for { k, v } <- value, into: %{} do
      { binary_to_existing_atom(k), v }
    end)
  end
end
