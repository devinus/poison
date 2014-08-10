defmodule Posion.EncoderTest do
  use ExUnit.Case

  alias Poison.EncodeError

  test "integers" do
    assert to_json(42) == "42"
  end

  test "floats" do
    assert to_json(99.99) == "99.99"
    assert to_json(9.9e100) == "9.9e100"
  end

  test "strings" do
    assert to_json("hello world") == ~s("hello world")
    assert to_json("hello\nworld") == ~s("hello\\nworld")
    assert to_json("\nhello\nworld\n") == ~s("\\nhello\\nworld\\n")

    assert to_json("\0") == ~s("\\u0000")
    assert to_json("☃", escape: :unicode) == ~s("\\u2603")
    assert to_json("𝄞", escape: :unicode) == ~s("\\uD834\\uDD1E")
    assert to_json("\x{2028}\x{2029}", escape: :javascript) == ~s("\\u2028\\u2029")
  end

  test "objects" do
    assert to_json(%{}) == "{}"
    assert to_json(%{foo: :bar}) == ~s({"foo":"bar"})
    assert to_json(%{"foo" => "bar"})  == ~s({"foo":"bar"})

    assert to_json(%{42.0 => "foo"}) == ~s({"42.0":"foo"})
  end

  test "arrays" do
    assert to_json([]) == "[]"
    assert to_json([1, 2, 3]) == "[1,2,3]"
  end

  test "unencodable" do
    assert_raise EncodeError, fn ->
      to_json(self)
    end
  end

  defp to_json(value, options \\ []) do
    IO.iodata_to_binary(Poison.Encoder.encode(value, options))
  end
end
