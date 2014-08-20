defmodule Posion.EncoderTest do
  use ExUnit.Case

  alias Poison.EncodeError

  test "Atom" do
    assert to_json(nil) == "null"
    assert to_json(true) == "true"
    assert to_json(false) == "false"
    assert to_json(:poison) == ~s("poison")
  end

  test "Integer" do
    assert to_json(42) == "42"
  end

  test "Float" do
    assert to_json(99.99) == "99.99"
    assert to_json(9.9e100) == "9.9e100"
  end

  test "BitString" do
    assert to_json("hello world") == ~s("hello world")
    assert to_json("hello\nworld") == ~s("hello\\nworld")
    assert to_json("\nhello\nworld\n") == ~s("\\nhello\\nworld\\n")

    assert to_json("\0") == ~s("\\u0000")
    assert to_json("☃", escape: :unicode) == ~s("\\u2603")
    assert to_json("𝄞", escape: :unicode) == ~s("\\uD834\\uDD1E")
    assert to_json("\x{2028}\x{2029}", escape: :javascript) == ~s("\\u2028\\u2029")
  end

  test "Map" do
    assert to_json(%{}) == "{}"
    assert to_json(%{foo: :bar}) == ~s({"foo":"bar"})
    assert to_json(%{"foo" => "bar"})  == ~s({"foo":"bar"})

    assert to_json(%{42.0 => "foo"}) == ~s({"42.0":"foo"})
  end

  test "List" do
    assert to_json([]) == "[]"
    assert to_json([1, 2, 3]) == "[1,2,3]"
  end

  test "Range" do
    assert to_json(1..3) == "[1,2,3]"
  end

  test "Stream" do
    range = 1..10
    assert to_json(Stream.take(range, 0)) == "[]"
    assert to_json(Stream.take(range, 3)) == "[1,2,3]"
  end

  # HashSet/HashDict have an unspecified order

  test "HashSet" do
    set = HashSet.new
    assert to_json(set) == "[]"

    set = set |> HashSet.put(1) |> HashSet.put(2)
    assert to_json(set) in ~w([1,2] [2,1])
  end

  test "HashDict" do
    dict = HashDict.new
    assert to_json(dict) == "{}"

    dict = dict |> HashDict.put(:foo, "bar") |> HashDict.put(:baz, "quux")
    assert to_json(dict) in ~w"""
    {"foo":"bar","baz":"quux"}
    {"baz":"quux","foo":"bar"}
    """
  end

  test "Keyword" do
    kw = Keyword.new
    assert to_json(kw) == "[]"

    kw = kw |> Keyword.put(:foo, "bar") |> Keyword.put(:baz, "quux")
    assert to_json(kw) in ~w"""
    {"foo":"bar","baz":"quux"}
    {"baz":"quux","foo":"bar"}
    """
  end

  test "EncodeError" do
    assert_raise EncodeError, fn ->
      to_json(self)
    end
  end

  defp to_json(value, options \\ []) do
    IO.iodata_to_binary(Poison.Encoder.encode(value, options))
  end
end
