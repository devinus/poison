defmodule Poison.EncoderTest do
  use ExUnit.Case, async: true

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

  test "Decimal" do
    Decimal.with_context(%Decimal.Context{precision: 36, rounding: :floor}, fn ->
      assert to_json(Decimal.new("1234.56789")) == "1234.56789"
      assert to_json(Decimal.div(Decimal.new("123456789123489123456789"), Decimal.new("1000"))) == "123456789123489123456.789"
    end)
  end

  test "BitString" do
    assert to_json("hello world") == ~s("hello world")
    assert to_json("hello\nworld") == ~s("hello\\nworld")
    assert to_json("\nhello\nworld\n") == ~s("\\nhello\\nworld\\n")

    assert to_json("\"") == ~s("\\"")
    assert to_json("\0") == ~s("\\u0000")
    assert to_json("☃", escape: :unicode) == ~s("\\u2603")
    assert to_json("𝄞", escape: :unicode) == ~s("\\uD834\\uDD1E")
    assert to_json("\x{2028}\x{2029}", escape: :javascript) == ~s("\\u2028\\u2029")
    assert to_json("áéíóúàèìòùâêîôûãẽĩõũ") == ~s("áéíóúàèìòùâêîôûãẽĩõũ")
  end

  test "Map" do
    assert to_json(%{}) == "{}"
    assert to_json(%{foo: :bar}) == ~s({"foo":"bar"})
    assert to_json(%{"foo" => "bar"})  == ~s({"foo":"bar"})
    assert to_json(%{foo: %{bar: %{baz: "baz"}}}, pretty: true) == """
    {
      "foo": {
        "bar": {
          "baz": "baz"
        }
      }
    }\
    """
  end

  test "List" do
    assert to_json([]) == "[]"
    assert to_json([1, 2, 3]) == "[1,2,3]"
    assert to_json([1, 2, 3], pretty: true) == """
    [
      1,
      2,
      3
    ]\
    """
  end

  test "Range" do
    assert to_json(1..3) == "[1,2,3]"
    assert to_json(1..3, pretty: true) == """
    [
      1,
      2,
      3
    ]\
    """
  end

  test "Stream" do
    range = 1..10
    assert to_json(Stream.take(range, 0)) == "[]"
    assert to_json(Stream.take(range, 3)) == "[1,2,3]"
    assert to_json(Stream.take(range, 3), pretty: true) == """
    [
      1,
      2,
      3
    ]\
    """
  end

  # HashSet/HashDict have an unspecified order

  test "HashSet" do
    set = HashSet.new
    assert to_json(set) == "[]"

    set = set |> HashSet.put(1) |> HashSet.put(2)

    assert to_json(set) in ~w([1,2] [2,1])
    assert to_json(set, pretty: true) in [
      """
      [
        1,
        2
      ]\
      """,
      """
      [
        2,
        1
      ]\
      """
    ]
  end

  test "HashDict" do
    dict = HashDict.new
    assert to_json(dict) == "{}"

    dict = dict |> HashDict.put(:foo, "bar") |> HashDict.put(:baz, "quux")

    assert to_json(dict) in ~w"""
    {"foo":"bar","baz":"quux"}
    {"baz":"quux","foo":"bar"}
    """

    assert to_json(dict, pretty: true) in [
      """
      {
        "foo": "bar",
        "baz": "quux"
      }\
      """,
      """
      {
        "baz": "quux",
        "foo": "bar"
      }\
      """
    ]
  end

  defmodule Derived do
    @derive [Poison.Encoder]
    defstruct name: ""
  end

  defmodule DerivedUsingOnly do
    @derive {Poison.Encoder, only: [:name]}
    defstruct name: "", size: 0
  end

  defmodule NonDerived do
    defstruct name: ""
  end

  test "@derive" do
    derived = %Derived{name: "derived"}
    non_derived = %NonDerived{name: "non-derived"}
    assert Poison.Encoder.impl_for!(derived) == Poison.Encoder.Poison.EncoderTest.Derived
    assert Poison.Encoder.impl_for!(non_derived) == Poison.Encoder.Any

    derived_using_only = %DerivedUsingOnly{name: "derived using :only", size: 10}
    assert Poison.decode!(to_json(derived_using_only)) == %{"name" => "derived using :only"}
  end

  test "EncodeError" do
    assert_raise EncodeError, fn ->
      to_json(self)
    end

    assert_raise EncodeError, fn ->
      assert to_json(%{42.0 => "foo"})
    end

    assert_raise EncodeError, fn ->
      assert to_json(<<0x80>>)
    end
  end

  defp to_json(value, options \\ []) do
    Poison.Encoder.encode(value, options) |> IO.iodata_to_binary
  end
end
