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

  defp transform(nil, _keys, _as, _options), do: nil

  defp transform(value, keys, %{__struct__: _} = as, options) do
    transform_struct(value, keys, as, options)
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
    Map.from_struct(as)
    |> Map.merge(value)
    |> do_transform_struct(keys, as, options)
  end

  defp transform_struct(value, keys, as, options) do
    Map.from_struct(as)
    |> Enum.reduce(%{}, fn {key, default}, acc ->
      string_key = if options[:dash] do
        key |> Atom.to_string() |> String.replace("_", "-")
      else
        key |> Atom.to_string()
      end
      Map.put(acc, key, Map.get(value, string_key, default))
    end)
    |> do_transform_struct(keys, as, options)
  end

  defp do_transform_struct(value, keys, as, options) do
    default = struct(as.__struct__)

    Map.from_struct(as)
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
    |> Poison.Decoder.decode(options)
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
