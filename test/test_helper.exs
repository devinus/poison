defmodule Poison.TestGenerators do
  use ExUnitProperties

  def json_string(options \\ []) do
    string(
      ~c(\b\t\n\f\r) ++ [0x20..0x7E, 0xA0..0xD7FF, 0xE000..0xFFFD, 0x10000..0x10FFFF],
      options
    )
  end

  def json_value do
    one_of([
      constant(nil),
      boolean(),
      integer(),
      float(),
      json_string()
    ])
  end

  def json_list(options \\ []) do
    list_of(json_value(), options)
  end

  def json_map(options \\ []) do
    map_of(json_string(min_length: 1), json_value(), options)
  end

  def json_complex_value do
    tree(
      json_value(),
      &one_of([
        list_of(&1),
        map_of(json_string(min_length: 1), &1)
      ])
    )
  end
end

ExUnit.configure(formatters: [ExUnit.CLIFormatter, JUnitFormatter])
ExUnit.start()
