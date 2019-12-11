defmodule Bench do
  alias Benchee.Formatters.{Console, HTML}

  def run_decode do
    Benchee.run(decode_jobs(),
      parallel: 8,
      warmup: 1,
      time: 10,
      memory_time: 1,
      pre_check: true,
      inputs:
        for name <- decode_inputs(), into: %{} do
          name
          |> read_data()
          |> (&{name, &1}).()
        end,
      before_each: fn input -> :binary.copy(input) end,
      after_scenario: fn _input -> gc() end,
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
      inputs:
        for name <- encode_inputs(), into: %{} do
          name
          |> read_data()
          |> Poison.decode!()
          |> (&{name, &1}).()
        end,
      after_scenario: fn _input -> gc() end,
      formatters: [
        {Console, extended_statistics: true},
        {HTML, extended_statistics: true, file: Path.expand("output/encode.html", __DIR__)}
      ]
    )
  end

  defp gc do
    request_id = System.monotonic_time()
    :erlang.garbage_collect(self(), async: request_id)

    receive do
      {:garbage_collect, ^request_id, _dead} -> :ok
    end
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
      "jiffy" => &:jiffy.decode(&1, [:return_maps, :use_nil]),
      "JSON" => &JSON.decode!/1,
      "jsone" => &:jsone.decode/1,
      "JSX" => &JSX.decode!(&1, [:strict]),
      "Poison" => &Poison.Parser.parse!/1
    }
  end

  defp encode_jobs do
    %{
      "Jason" => &Jason.encode!/1,
      "jiffy" => &:jiffy.encode/1,
      "JSON" => &JSON.encode!/1,
      "jsone" => &:jsone.encode/1,
      "JSX" => &JSX.encode!/1,
      "Poison" => &Poison.encode!/1
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
      "Stocks",
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
