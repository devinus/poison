defmodule EncoderBench do
  use Benchfella

  # Lists
  bench "lists (Poison)", [list: gen_list] do
    Poison.encode!(list)
  end

  bench "lists (jiffy)", [list: gen_list] do
    :jiffy.encode(list)
  end

  bench "lists (JSX)", [list: gen_list] do
    JSX.encode!(list)
  end

  bench "lists (Jazz)", [list: gen_list] do
    Jazz.encode!(list)
  end

  # Maps
  bench "maps (Poison)", [map: gen_map] do
    Poison.encode!(map)
  end

  bench "maps (jiffy)", [map: gen_map] do
    :jiffy.encode(map)
  end

  bench "maps (JSX)", [map: gen_map] do
    JSX.encode!(map)
  end

  bench "maps (Jazz)", [map: gen_map] do
    Jazz.encode!(map)
  end

  # Strings
  bench "strings (Poison)", [string: gen_string] do
    Poison.encode!(string)
  end

  bench "strings (jiffy)", [string: gen_string] do
    :jiffy.encode(string)
  end

  bench "strings (JSX)", [string: gen_string] do
    JSX.encode!(string)
  end

  bench "strings (Jazz)", [string: gen_string] do
    Jazz.encode!(string)
  end

  # String escaping
  bench "string escaping (Poison)", [string: gen_string] do
    Poison.encode!(string, escape: :unicode)
  end

  bench "string escaping (jiffy)", [string: gen_string] do
    :jiffy.encode(string, [:uescape])
  end

  bench "string escaping (JSX)", [string: gen_string] do
    JSX.encode!(string, [:uescape])
  end

  bench "string escaping (Jazz)", [string: gen_string] do
    Jazz.encode!(string, escape: :unicode)
  end

  bench "Poison", [data: gen_data] do
    Poison.encode!(data)
  end

  bench "jiffy", [data: gen_data] do
    :jiffy.encode(data)
  end

  bench "JSX", [data: gen_data] do
    JSX.encode!(data)
  end

  bench "Jazz", [data: gen_data] do
    Jazz.encode!(data)
  end

  bench "Poison (pretty)", [data: gen_data] do
    Poison.encode!(data, pretty: true)
  end

  bench "jiffy (pretty)", [data: gen_data] do
    :jiffy.encode(data, [:pretty])
  end

  bench "JSX (pretty)", [data: gen_data] do
    JSX.prettify!(JSX.encode!(data))
  end

  bench "Jazz (pretty)", [data: gen_data] do
    Jazz.encode!(data, pretty: true)
  end

  defp gen_list do
    Enum.to_list(1..1000)
  end

  defp gen_map do
    Stream.map(?A..?Z, &<<&1>>) |> Stream.with_index |> Enum.into(%{})
  end

  defp gen_string do
    File.read!(Path.expand("data/UTF-8-demo.txt", __DIR__))
  end

  defp gen_data do
    File.read!(Path.expand("data/generated.json", __DIR__)) |> Poison.decode!
  end
end
