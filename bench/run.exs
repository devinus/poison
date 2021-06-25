defmodule Bench do
  alias Benchee.Formatters.{Console, HTML}

  def run_decode do
    Benchee.run(decode_jobs(),
      parallel: 8,
      warmup: 1,
      time: 10,
      memory_time: 1,
      pre_check: true,
      load: Path.join(__DIR__, "decode.benchee"),
      save: [path: Path.join(__DIR__, "decode.benchee")],
      inputs:
        for name <- decode_inputs(), into: %{} do
          name
          |> read_data()
          |> (&{name, &1}).()
        end,
      before_each: fn input -> :binary.copy(input) end,
      formatters: [
        {Console, extended_statistics: true},
        {HTML, extended_statistics: true, file: Path.expand("output/decode.html", __DIR__)}
      ]
    )
  end

  def run_encode do
    Benchee.run(encode_jobs(),
      parallel: 8,
      warmup: 1,
      time: 10,
      memory_time: 1,
      pre_check: true,
      load: Path.join(__DIR__, "encode.benchee"),
      save: [path: Path.join(__DIR__, "encode.benchee")],
      inputs:
        for name <- encode_inputs(), into: %{} do
          name
          |> read_data()
          |> Poison.decode!()
          |> (&{name, &1}).()
        end,
      formatters: [
        {Console, extended_statistics: true},
        {HTML, extended_statistics: true, file: Path.expand("output/encode.html", __DIR__)}
      ]
    )
  end

  defp read_data(name) do
    name
    |> String.downcase()
    |> String.replace(~r/([^\w]|-|_)+/, "-")
    |> String.trim("-")
    |> (&"data/#{&1}.json").()
    |> Path.expand(__DIR__)
    |> File.read!()
  end

  defp decode_jobs do
    %{
      "Jason" => &Jason.decode!/1,
      "Jaxon" => &Jaxon.decode!/1,
      "jiffy" => &:jiffy.decode(&1, [:return_maps, :use_nil]),
      "JSON" => &JSON.decode!/1,
      "jsone" => &:jsone.decode/1,
      "JSX" => &JSX.decode!(&1, [:strict]),
      "Poison" => &Poison.Parser.parse!/1,
      "Tiny" => &Tiny.decode!/1
    }
  end

  defp encode_jobs do
    %{
      "Jason" => &Jason.encode!/1,
      "Jaxon" => &Jaxon.encode!/1,
      "jiffy" => &:jiffy.encode(&1, [:use_nil]),
      "JSON" => &JSON.encode!/1,
      "jsone" => &:jsone.encode/1,
      "JSX" => &JSX.encode!/1,
      "Poison" => &Poison.encode!/1,
      "Tiny" => &Tiny.encode!/1
    }
  end

  defp decode_inputs do
    [
      "Benchee",
      "Blockchain",
      "GeoJSON",
      "Giphy",
      "GitHub",
      "GovTrack",
      "Issue 90",
      "JSON Generator (Pretty)",
      "JSON Generator",
      "Pokedex",
      "Reddit",
      "UTF-8 escaped",
      "UTF-8 unescaped"
    ]
  end

  defp encode_inputs do
    decode_inputs() -- ["JSON Generator (Pretty)"]
  end
end

Bench.run_decode()
Bench.run_encode()
