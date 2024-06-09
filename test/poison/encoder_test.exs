defmodule Poison.EncoderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Poison.TestGenerators

  import Poison, only: [encode!: 1, encode!: 2]
  alias Poison.{EncodeError, Encoder}

  test "Atom" do
    assert encode!(nil) == "null"
    assert encode!(true) == "true"
    assert encode!(false) == "false"
    assert encode!(:poison) == ~s("poison")
  end

  property "Atom" do
    check all(
            str <- filter(json_string(max_length: 255), &(&1 not in ~w(nil true false))),
            # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
            value = String.to_atom(str)
          ) do
      assert encode!(value) == inspect(str)
    end
  end

  test "Integer" do
    assert encode!(42) == "42"
    assert encode!(576_460_752_303_423_488) == "576460752303423488"
  end

  property "Integer" do
    check all(value <- integer()) do
      assert encode!(value) == to_string(value)
    end
  end

  test "Float" do
    assert encode!(99.99) == "99.99"
    assert encode!(9.9e100) == "9.9e100"
    assert encode!(9.9e-100) == "9.9e-100"
  end

  property "Float" do
    check all(value <- float()) do
      assert encode!(value) == to_string(value)
    end
  end

  test "BitString" do
    assert encode!("") == ~s("")
    assert encode!("hello world") == ~s("hello world")
    assert encode!("hello\nworld") == ~s("hello\\nworld")
    assert encode!("\nhello\nworld\n") == ~s("\\nhello\\nworld\\n")

    assert encode!("\"") == ~s("\\"")
    assert encode!("\0") == ~s("\\u0000")
    assert encode!(<<31>>) == ~s("\\u001F")
    assert encode!("☃", escape: :unicode) == ~s("\\u2603")
    assert encode!("𝄞", escape: :unicode) == ~s("\\uD834\\uDD1E")
    assert encode!("\u2028\u2029", escape: :javascript) == ~s("\\u2028\\u2029")
    assert encode!("</script>", escape: :html_safe) == ~s("\\u003C/script\\u003E")

    assert encode!("\uCCCC</script>\uCCCC", escape: :html_safe) ==
             ~s("쳌\\u003C/script\\u003E쳌")

    assert encode!(~s(<script>var s = "\u2028\u2029";</script>), escape: :html_safe) ==
             ~s("\\u003Cscript\\u003Evar s = \\\"\\u2028\\u2029\\\";\\u003C/script\\u003E")

    assert encode!("<!-- comment -->", escape: :html_safe) == ~s("\\u003C!-- comment --\\u003E")
    assert encode!("one & two", escape: :html_safe) == ~s("one \\u0026 two")

    assert encode!("áéíóúàèìòùâêîôûãẽĩõũ") == ~s("áéíóúàèìòùâêîôûãẽĩõũ")
  end

  property "BitString" do
    check all(value <- json_string(min_length: 1)) do
      assert encode!(value) == inspect(value)
    end

    check all(
            str <- string(Enum.concat(0xA0..0xD7FF, 0xE000..0x10000), min_length: 1),
            elem <- member_of(String.codepoints(str)),
            <<codepoint::utf8>> = elem
          ) do
      seq = codepoint |> Integer.to_string(16) |> String.pad_leading(4, "0")
      assert encode!(<<codepoint::utf8>>, escape: :unicode) == ~s("\\u#{seq}")
    end

    check all(
            hi <- integer(0xD800..0xDBFF),
            lo <- integer(0xDC00..0xDFFF)
          ) do
      seq1 = hi |> Integer.to_string(16) |> String.pad_leading(4, "0")
      seq2 = lo |> Integer.to_string(16) |> String.pad_leading(4, "0")
      <<codepoint::utf16>> = <<hi::16, lo::16>>
      value = :unicode.characters_to_binary([codepoint], :utf16, :utf8)
      assert encode!(value, escape: :unicode) == ~s("\\u#{seq1}\\u#{seq2}")
    end
  end

  property "List" do
    check all(value <- json_list(min_length: 1)) do
      assert String.match?(encode!(value), ~r/^\[(([^,]+,)|[^\]]+){1,#{length(value)}}\]$/)
    end
  end

  property "Tuple" do
    check all(value <- json_list(min_length: 1)) do
      assert String.match?(to_json({value}), ~r/^\{.*\}$/)
    end
  end

  test "Map" do
    assert encode!(%{}) == "{}"
    assert encode!(%{"foo" => "bar"}) == ~s({"foo":"bar"})
    assert encode!(%{foo: :bar}) == ~s({"foo":"bar"})
    assert encode!(%{42 => :bar}) == ~s({"42":"bar"})

    assert encode!(%{foo: %{bar: %{baz: "baz"}}}, pretty: true) ==
             "{\n  \"foo\": {\n    \"bar\": {\n      \"baz\": \"baz\"\n    }\n  }\n}"

    multi_key_map = %{"foo" => "foo1", :foo => "foo2"}
    assert encode!(multi_key_map) == ~s({"foo":"foo1","foo":"foo2"})
    error = %EncodeError{message: "duplicate key found: :foo", value: "foo"}
    assert Poison.encode(multi_key_map, strict_keys: true) == {:error, error}
  end

  property "Map" do
    check all(value <- json_map(min_length: 1)) do
      assert String.match?(encode!(value), ~r/^\{([^:]+:[^,]+){1,#{map_size(value)}}\}$/)
    end
  end

  test "Range" do
    assert encode!(1..3) == "[1,2,3]"
    assert encode!(1..3, pretty: true) == "[\n  1,\n  2,\n  3\n]"
  end

  test "Stream" do
    range = 1..10
    assert encode!(Stream.take(range, 0)) == "[]"
    assert encode!(Stream.take(range, 3)) == "[1,2,3]"
    assert encode!(Stream.take(range, 3), pretty: true) == "[\n  1,\n  2,\n  3\n]"
  end

  # MapSet have an unspecified order

  test "MapSet" do
    set = MapSet.new()
    assert encode!(set) == "[]"

    set = set |> MapSet.put(1) |> MapSet.put(2)
    assert encode!(set) in ~w([1,2] [2,1])
    assert encode!(set, pretty: true) in ["[\n  1,\n  2\n]", "[\n  2,\n  1\n]"]
  end

  test "Time" do
    {:ok, time} = Time.new(12, 13, 14)
    assert encode!(time) == ~s("12:13:14")
  end

  test "Date" do
    {:ok, date} = Date.new(2000, 1, 1)
    assert encode!(date) == ~s("2000-01-01")
  end

  test "NaiveDateTime" do
    {:ok, datetime} = NaiveDateTime.new(2000, 1, 1, 12, 13, 14)
    assert encode!(datetime) == ~s("2000-01-01T12:13:14")
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

    assert encode!(datetime) == ~s("2000-01-01T12:13:14+00:30")

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

    assert encode!(datetime) == ~s("2000-01-01T12:13:14.050Z")
  end

  test "Date.Range" do
    assert encode!(Date.range(~D[1969-08-15], ~D[1969-08-18])) ==
             ~s(["1969-08-15","1969-08-16","1969-08-17","1969-08-18"])
  end

  test "URI" do
    uri = URI.parse("https://devinus.io")
    assert encode!(uri) == ~s("https://devinus.io")
  end

  test "Decimal" do
    decimal = Decimal.new("99.9")
    assert encode!(decimal) == "99.9"
  end

  property "Decimal" do
    check all(value <- map(float(), &Decimal.from_float/1)) do
      assert encode!(value) == to_string(value)
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

    assert Poison.decode!(encode!(derived_using_only)) == %{
             "name" => "derived using :only"
           }

    derived_using_except = %DerivedUsingExcept{
      name: "derived using :except",
      size: 10
    }

    assert Poison.decode!(encode!(derived_using_except)) == %{"size" => 10}
  end

  test "EncodeError" do
    assert_raise EncodeError, fn ->
      encode!(make_ref())
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
      assert encode!(value, options) != ""
    end
  end
end
