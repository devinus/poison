defmodule Poison.Transform do
  @doc "Transform an object key"

  @callback transform(String.t) :: String.t

  # Identity fn is the default
  # However a macro should be used to compile the optional transformer in
  def transform(string) do
    string
  end
end

defmodule Poison.CamelCase do
  @behaviour Poison.Transform

  def transform(string) do
    [h|t] = string |> Macro.camelize |> String.codepoints
    String.downcase(h) <> to_string(t)
  end
end

defmodule Poison.SnakeCase do
  @behaviour Poison.Transform

  def transform(string) do
    Macro.underscore(string)
  end
end
