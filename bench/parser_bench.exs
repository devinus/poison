defmodule ParserBench do
  use Benchfella

  # We wont test Jazz, since it's parser is simply an earlier version of
  # Poison's parser.

  bench "Poison", [json: gen_json] do
    Poison.Parser.parse!(json)
  end

  bench "jiffy", [json: gen_json] do
    :jiffy.decode(json, [:return_maps])
  end

  bench "JSX", [json: gen_json] do
    JSX.decode!(json, [:strict])
  end

  # UTF8 escaping
  bench "UTF-8 unescaping (Poison)", [utf8: gen_utf8] do
    Poison.Parser.parse!(utf8)
  end

  bench "UTF-8 unescaping (jiffy)", [utf8: gen_utf8] do
    :jiffy.decode(utf8)
  end

  bench "UTF-8 unescaping (JSX)", [utf8: gen_utf8] do
    JSX.decode!(utf8, [:strict])
  end

  defp gen_json do
    File.read!(Path.expand("data/generated.json", __DIR__))
  end

  defp gen_utf8 do
    text = File.read!(Path.expand("data/UTF-8-demo.txt", __DIR__))
    Poison.encode!(text) |> IO.iodata_to_binary
  end
end
