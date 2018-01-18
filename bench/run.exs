encode_jobs = %{
  "Poison" => &Poison.encode!/1,
  "JSX" => &JSX.encode!/1,
  "Tiny" => &Tiny.encode!/1,
  "jsone" => &:jsone.encode/1,
  "jiffy" => &:jiffy.encode/1,
  "JSON" => &JSON.encode!/1
}

encode_inputs = [
  "GitHub",
  "Giphy",
  "GovTrack",
  "Blockchain",
  "Pokedex",
  "JSON Generator",
  "UTF-8 unescaped",
  "Issue 90"
]

decode_jobs = %{
  "Poison" => &Poison.decode!/1,
  "JSX" => &JSX.decode!(&1, [:strict]),
  "Tiny" => &Tiny.decode!/1,
  "jsone" => &:jsone.decode/1,
  "jiffy" => &:jiffy.decode(&1, [:return_maps]),
  "JSON" => &JSON.decode!/1
}

decode_inputs = [
  "GitHub",
  "Giphy",
  "GovTrack",
  "Blockchain",
  "Pokedex",
  "JSON Generator",
  "JSON Generator (Pretty)",
  "UTF-8 escaped",
  "UTF-8 unescaped",
  "Issue 90"
]

read_data = fn name ->
  name
  |> String.downcase()
  |> String.replace(~r/([^\w]|-|_)+/, "-")
  |> String.trim("-")
  |> (&"data/#{&1}.json").()
  |> Path.expand(__DIR__)
  |> File.read!()
end

Benchee.run(
  encode_jobs,
  parallel: 4,
  # warmup: 5,
  # time: 30,
  inputs:
    for name <- encode_inputs, into: %{} do
      name
      |> read_data.()
      |> Poison.decode!()
      |> (&{name, &1}).()
    end,
  formatters: [
    &Benchee.Formatters.HTML.output/1,
    &Benchee.Formatters.Console.output/1
  ],
  formatter_options: [
    html: [
      file: Path.expand("output/encode.html", __DIR__)
    ]
  ]
)

Benchee.run(
  decode_jobs,
  parallel: 4,
  # warmup: 5,
  # time: 30,
  inputs:
    for name <- decode_inputs, into: %{} do
      name
      |> read_data.()
      |> (&{name, &1}).()
    end,
  formatters: [
    &Benchee.Formatters.HTML.output/1,
    &Benchee.Formatters.Console.output/1
  ],
  formatter_options: [
    html: [
      file: Path.expand("output/decode.html", __DIR__)
    ]
  ]
)
