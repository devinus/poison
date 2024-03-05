defmodule Poison.EncoderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Poison.TestGenerators

  alias Poison.{EncodeError, Encoder}

  test "Atom" do
    assert to_json(nil) == "null"
    assert to_json(true) == "true"
    assert to_json(false) == "false"
    assert to_json(:poison) == ~s("poison")
  end

  property "Atom" do
    check all(
            str <- filter(json_string(max_length: 255), &(&1 not in ~w(nil true false))),
            # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
            value = String.to_atom(str)
          ) do
      assert to_json(value) == inspect(str)
    end
  end

  test "Integer" do
    assert to_json(42) == "42"
  end

  property "Integer" do
    check all(value <- integer()) do
      assert to_json(value) == to_string(value)
    end
  end

  test "Float" do
    assert to_json(99.99) == "99.99"
    assert to_json(9.9e100) == "9.9e100"
  end

  property "Float" do
    check all(value <- float()) do
      assert to_json(value) == to_string(value)
    end
  end

  test "BitString" do
    assert to_json("hello world") == ~s("hello world")
    assert to_json("hello\nworld") == ~s("hello\\nworld")
    assert to_json("\nhello\nworld\n") == ~s("\\nhello\\nworld\\n")

    assert to_json("\"") == ~s("\\"")
    assert to_json("\0") == ~s("\\u0000")
    assert to_json(<<31>>) == ~s("\\u001F")
    assert to_json("☃", escape: :unicode) == ~s("\\u2603")
    assert to_json("𝄞", escape: :unicode) == ~s("\\uD834\\uDD1E")
    assert to_json("\u2028\u2029", escape: :javascript) == ~s("\\u2028\\u2029")
    assert to_json("</script>", escape: :html_safe) == ~s("<\\/script>")

    assert to_json("\uCCCC</script>\uCCCC", escape: :html_safe) ==
             ~s("쳌<\\/script>쳌")

    assert to_json(~s(<script>var s = "\u2028\u2029";</script>),
             escape: :html_safe
           ) == ~s("<script>var s = \\\"\\u2028\\u2029\\\";<\\/script>")

    assert to_json("áéíóúàèìòùâêîôûãẽĩõũ") == ~s("áéíóúàèìòùâêîôûãẽĩõũ")
  end

  property "BitString" do
    check all(value <- json_string()) do
      assert to_json(value) == inspect(value)
    end

    check all(
            str <- string(Enum.concat(0xA0..0xD7FF, 0xE000..0x10000), min_length: 1),
            elem <- member_of(String.codepoints(str)),
            <<codepoint::utf8>> = elem
          ) do
      seq = codepoint |> Integer.to_string(16) |> String.pad_leading(4, "0")
      assert to_json(<<codepoint::utf8>>, escape: :unicode) == ~s("\\u#{seq}")
    end

    check all(
            hi <- integer(0xD800..0xDBFF),
            lo <- integer(0xDC00..0xDFFF)
          ) do
      seq1 = hi |> Integer.to_string(16) |> String.pad_leading(4, "0")
      seq2 = lo |> Integer.to_string(16) |> String.pad_leading(4, "0")
      <<codepoint::utf16>> = <<hi::16, lo::16>>
      value = :unicode.characters_to_binary([codepoint], :utf16, :utf8)
      assert to_json(value, escape: :unicode) == ~s("\\u#{seq1}\\u#{seq2}")
    end
  end

  property "List" do
    check all(value <- json_list(min_length: 1)) do
      assert String.match?(to_json(value), ~r/^\[.*\]$/)
    end
  end

  test "Map" do
    assert to_json(%{}) == "{}"
    assert to_json(%{"foo" => "bar"}) == ~s({"foo":"bar"})
    assert to_json(%{foo: :bar}) == ~s({"foo":"bar"})
    assert to_json(%{42 => :bar}) == ~s({"42":"bar"})

    assert to_json(%{foo: %{bar: %{baz: "baz"}}}, pretty: true) == """
           {
             "foo": {
               "bar": {
                 "baz": "baz"
               }
             }
           }\
           """

    multi_key_map = %{"foo" => "foo1", :foo => "foo2"}
    assert to_json(multi_key_map) == ~s({"foo":"foo1","foo":"foo2"})
    error = %EncodeError{message: "duplicate key found: :foo", value: "foo"}
    assert Poison.encode(multi_key_map, strict_keys: true) == {:error, error}
  end

  property "Map" do
    check all(value <- json_map(min_length: 1)) do
      assert String.match?(to_json(value), ~r/^{.*}$/)
    end
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

  # MapSet/HashSet have an unspecified order

  test "MapSet/HashSet" do
    for type <- [MapSet, HashSet] do
      set = type.new()
      assert to_json(set) == "[]"

      set = set |> type.put(1) |> type.put(2)

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
  end

  test "Time" do
    {:ok, time} = Time.new(12, 13, 14)
    assert to_json(time) == ~s("12:13:14")
  end

  test "Date" do
    {:ok, date} = Date.new(2000, 1, 1)
    assert to_json(date) == ~s("2000-01-01")
  end

  test "NaiveDateTime" do
    {:ok, datetime} = NaiveDateTime.new(2000, 1, 1, 12, 13, 14)
    assert to_json(datetime) == ~s("2000-01-01T12:13:14")
  end

  test "DateTime" do
    datetime = %DateTime{
      year: 2000,
      month: 1,
      day: 1,
      hour: 12,
      minute: 13,
      second: 14,
      microsecond: {0, 0},
      zone_abbr: "CET",
      time_zone: "Europe/Warsaw",
      std_offset: -1800,
      utc_offset: 3600
    }

    assert to_json(datetime) == ~s("2000-01-01T12:13:14+00:30")

    datetime = %DateTime{
      year: 2000,
      month: 1,
      day: 1,
      hour: 12,
      minute: 13,
      second: 14,
      microsecond: {50_000, 3},
      zone_abbr: "UTC",
      time_zone: "Etc/UTC",
      std_offset: 0,
      utc_offset: 0
    }

    assert to_json(datetime) == ~s("2000-01-01T12:13:14.050Z")
  end

  test "URI" do
    uri = URI.parse("https://devinus.io")
    assert to_json(uri) == ~s("https://devinus.io")
  end

  test "Decimal" do
    decimal = Decimal.new("99.9")
    assert to_json(decimal) == "99.9"
  end

  property "Decimal" do
    check all(value <- map(float(), &Decimal.from_float/1)) do
      assert to_json(value) == to_string(value)
    end
  end

  defmodule Derived do
    @derive [Poison.Encoder]
    defstruct name: ""
  end

  defmodule DerivedUsingOnly do
    @derive {Poison.Encoder, only: [:name]}
    defstruct name: "", size: 0
  end

  defmodule DerivedUsingExcept do
    @derive {Poison.Encoder, except: [:name]}
    defstruct name: "", size: 0
  end

  defmodule NonDerived do
    defstruct name: ""
  end

  test "@derive" do
    derived = %Derived{name: "derived"}
    non_derived = %NonDerived{name: "non-derived"}
    assert Encoder.impl_for!(derived) == Encoder.Poison.EncoderTest.Derived
    assert Encoder.impl_for!(non_derived) == Encoder.Any

    derived_using_only = %DerivedUsingOnly{
      name: "derived using :only",
      size: 10
    }

    assert Poison.decode!(to_json(derived_using_only)) == %{
             "name" => "derived using :only"
           }

    derived_using_except = %DerivedUsingExcept{
      name: "derived using :except",
      size: 10
    }

    assert Poison.decode!(to_json(derived_using_except)) == %{"size" => 10}
  end

  test "EncodeError" do
    assert_raise EncodeError, fn ->
      to_json(self())
    end
  end

  property "complex nested input" do
    check all(
            value <- json_complex_value(),
            options <-
              optional_map(%{
                escape: one_of([:unicode, :javascript, :html_safe]),
                pretty: boolean(),
                indent: positive_integer(),
                offset: positive_integer()
              })
          ) do
      assert to_json(value, options) != ""
    end
  end

  defp to_json(value, options \\ []) do
    value
    |> Encoder.encode(Map.new(options))
    |> IO.iodata_to_binary()
  end
end
