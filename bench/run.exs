defmodule Bench do
  alias Benchee.Formatters.{Console, HTML, Markdown}

  def run_decode do
    Benchee.run(decode_jobs(),
      title: "Decode",
      parallel: 4,
      warmup: 1,
      time: 10,
      memory_time: 1,
      reduction_time: 1,
      pre_check: true,
      measure_function_call_overhead: true,
      load: Path.join(__DIR__, "decode.benchee"),
      save: [path: Path.join(__DIR__, "decode.benchee")],
      inputs:
        for name <- decode_inputs(), into: %{} do
          name
          |> read_data()
          |> (&{name, &1}).()
        end,
      formatters: [
        {Console, extended_statistics: true},
        {Markdown, file: Path.expand("output/decode.md", __DIR__)},
        {HTML, auto_open: false, file: Path.expand("output/decode.html", __DIR__)}
      ]
    )
  end

  def run_encode do
    Benchee.run(encode_jobs(),
      title: "Encode",
      parallel: 4,
      warmup: 1,
      time: 10,
      memory_time: 1,
      reduction_time: 1,
      pre_check: true,
      measure_function_call_overhead: true,
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
        {Markdown, file: Path.expand("output/encode.md", __DIR__)},
        {HTML, auto_open: false, file: Path.expand("output/encode.html", __DIR__)}
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
    jobs = %{
      "Jason" => &Jason.decode!/1,
      "jiffy" => &:jiffy.decode(&1, [:return_maps, :use_nil]),
      "jsone" => &:jsone.decode(&1, [:reject_invalid_utf8, duplicate_map_keys: :last]),
      "JSX" => &JSX.decode!(&1, [:strict]),
      "Poison" => &Poison.Parser.parse!/1,
      "Tiny" => &Tiny.decode!/1,
      "Thoas" => &:thoas.decode/1
    }

    if Code.ensure_loaded?(:json) do
      Map.put(jobs, "json", &:json.decode/1)
    else
      jobs
    end
  end

  defp encode_jobs do
    jobs = %{
      "Jason" => &Jason.encode_to_iodata!/1,
      "jiffy" => &:jiffy.encode(&1, [:use_nil]),
      "jsone" => &:jsone.encode/1,
      "JSX" => &JSX.encode!(&1, [:strict]),
      "Poison" => &Poison.encode_to_iodata!/1,
      "Tiny" => &Tiny.encode_to_iodata!/1,
      "Thoas" => &:thoas.encode_to_iodata/1
    }

    if Code.ensure_loaded?(:json) do
      Map.put(jobs, "json", &:json.encode/1)
    else
      jobs
    end
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
