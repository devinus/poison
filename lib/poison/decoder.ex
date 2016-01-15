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

  # defp transform(value, keys, as, options) when is_atom(as) do
  #   transform_struct(value, keys, %{__struct__: as}, options)
  # end

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
        nil -> acc
        value -> Map.put(acc, key, transform(value, keys, as, options))
      end
    end)
  end

  defp transform_struct(value, keys, %{__struct__: struct} = as, options) when keys in [:atoms, :atoms!] do
    Enum.into(Map.from_struct(as), %{}, fn {key, default} ->
      {key, transform(Map.get(value, key, default), keys, default, options)}
    end)
    |> Map.put(:__struct__, struct)
    |> Poison.Decoder.decode(options)
  end

  defp transform_struct(value, keys, %{__struct__: struct} = as, options) do
    Enum.into(Map.from_struct(as), %{}, fn {key, default} ->
      {key, transform(Map.get(value, Atom.to_string(key), default), keys, default, options)}
    end)
    |> Map.put(:__struct__, struct)
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
