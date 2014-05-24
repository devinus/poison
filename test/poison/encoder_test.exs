defmodule Posion.EncoderTest do
  use ExUnit.Case

  test "numbers" do
    assert to_json(42) == "42"
    assert to_json(99.99) == "99.99"
  end

  test "strings" do
    assert to_json("hello world") == ~s("hello world")
    assert to_json("hello\nworld") == ~s("hello\\nworld")
    assert to_json("\nhello\nworld\n") == ~s("\\nhello\\nworld\\n")
  end

  test "objects" do
  end

  test "arrays" do
  end

  defp to_json(value) do
    iodata_to_binary(Poison.Encoder.encode(value))
  end
end
