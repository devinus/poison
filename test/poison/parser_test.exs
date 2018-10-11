defmodule Poison.ParserTest do
  use ExUnit.Case, async: true

  import Poison.Parser
  alias Poison.ParseError

  test "numbers" do
    assert_raise ParseError, "Unexpected end of input at position 1", fn ->
      parse!("-")
    end

    assert_raise ParseError, "Unexpected token at position 1: -", fn ->
      parse!("--1")
    end

    assert_raise ParseError, "Unexpected token at position 1: 1", fn ->
      parse!("01")
    end

    assert_raise ParseError, "Unexpected token at position 0: .", fn ->
      parse!(".1")
    end

    assert_raise ParseError, "Unexpected end of input at position 2", fn ->
      parse!("1.")
    end

    assert_raise ParseError, "Unexpected end of input at position 2", fn ->
      parse!("1e")
    end

    assert_raise ParseError, "Unexpected end of input at position 5", fn ->
      parse!("1.0e+")
    end

    assert_raise ParseError,
                 ~s(Cannot parse value at position 0: "100.0e999"),
                 fn ->
                   parse!("100e999")
                 end

    assert parse!("0") == 0
    assert parse!("1") == 1
    assert parse!("-0") == 0
    assert parse!("-1") == -1
    assert parse!("0.1") == 0.1
    assert parse!("-0.1") == -0.1
    assert parse!("0e0") == 0
    assert parse!("0E0") == 0
    assert parse!("1e0") == 1
    assert parse!("1E0") == 1
    assert parse!("1.0e0") == 1.0
    assert parse!("1e+0") == 1
    assert parse!("1.0e+0") == 1.0
    assert parse!("0.1e1") == 0.1e1
    assert parse!("0.1e-1") == 0.1e-1
    assert parse!("99.99e99") == 99.99e99
    assert parse!("-99.99e-99") == -99.99e-99
    assert parse!("123456789.123456789e123") == 123_456_789.123456789e123
  end

  test "strings" do
    assert_raise ParseError, "Unexpected end of input at position 1", fn ->
      parse!(~s("))
    end

    assert_raise ParseError, "Unexpected end of input at position 2", fn ->
      parse!(~s("\\"))
    end

    assert_raise ParseError, "Unexpected token at position 1: k", fn ->
      parse!(~s("\\k"))
    end

    assert_raise ParseError, "Unexpected end of input at position 1", fn ->
      parse!(<<34, 128, 34>>)
    end

    assert_raise ParseError, "Unexpected end of input at position 7", fn ->
      parse!(~s("\\u2603\\"))
    end

    assert_raise ParseError, "Unexpected end of input at position 39", fn ->
      parse!(~s("Here's a snowman for you: ☃. Good day!))
    end

    assert_raise ParseError, "Unexpected end of input at position 2", fn ->
      parse!(~s("𝄞))
    end

    assert_raise ParseError, "Unexpected token at position 0: á", fn ->
      parse!(~s(á))
    end

    assert_raise ParseError, "Unexpected token at position 0: \\x1F", fn ->
      parse!(~s(\u001F))
    end

    assert_raise ParseError,
                 ~s(Cannot parse value at position 1: "\\\\ud8aa\\\\udcxx"),
                 fn ->
                   parse!(~s("\\ud8aa\\udcxx"))
                 end

    assert_raise ParseError,
                 ~s(Cannot parse value at position 1: "\\\\uxxxx"),
                 fn ->
                   parse!(~s("\\uxxxx"))
                 end

    assert parse!(~s("\\"\\\\\\/\\b\\f\\n\\r\\t")) == ~s("\\/\b\f\n\r\t)
    assert parse!(~s("\\u2603")) == "☃"
    assert parse!(~s("\\u2028\\u2029")) == "\u2028\u2029"
    assert parse!(~s("\\uD834\\uDD1E")) == "𝄞"
    assert parse!(~s("\\uD834\\uDD1E")) == "𝄞"
    assert parse!(~s("\\uD799\\uD799")) == "힙힙"
    assert parse!(~s("✔︎")) == "✔︎"
  end

  test "objects" do
    assert_raise ParseError, "Unexpected end of input at position 1", fn ->
      parse!("{")
    end

    assert_raise ParseError, "Unexpected token at position 1: ,", fn ->
      parse!("{,")
    end

    assert_raise ParseError, "Unexpected token at position 6: }", fn ->
      parse!(~s({"foo"}))
    end

    assert_raise ParseError, "Unexpected token at position 14: }", fn ->
      parse!(~s({"foo": "bar",}))
    end

    assert parse!("{}") == %{}
    assert parse!(~s({"foo": "bar"})) == %{"foo" => "bar"}

    expected = %{"foo" => "bar", "baz" => "quux"}
    assert parse!(~s({"foo": "bar", "baz": "quux"})) == expected

    expected = %{"foo" => %{"bar" => "baz"}}
    assert parse!(~s({"foo": {"bar": "baz"}})) == expected
  end

  test "arrays" do
    assert_raise ParseError, "Unexpected end of input at position 1", fn ->
      parse!("[")
    end

    assert_raise ParseError, "Unexpected token at position 1: ,", fn ->
      parse!("[,")
    end

    assert_raise ParseError, "Unexpected token at position 3: ]", fn ->
      parse!("[1,]")
    end

    assert parse!("[]") == []
    assert parse!("[1, 2, 3]") == [1, 2, 3]
    assert parse!(~s(["foo", "bar", "baz"])) == ["foo", "bar", "baz"]
    assert parse!(~s([{"foo": "bar"}])) == [%{"foo" => "bar"}]
  end

  test "whitespace" do
    assert_raise ParseError, "Unexpected end of input at position 0", fn ->
      parse!("")
    end

    assert_raise ParseError, "Unexpected end of input at position 4", fn ->
      parse!("    ")
    end

    assert parse!("  [  ]  ") == []
    assert parse!("  {  }  ") == %{}

    assert parse!("  [  1  ,  2  ,  3  ]  ") == [1, 2, 3]

    expected = %{"foo" => "bar", "baz" => "quux"}

    assert parse!(~s(  {  "foo"  :  "bar"  ,  "baz"  :  "quux"  }  )) ==
             expected

    assert parse!(<<0xEF, 0xBB, 0xBF>> <> ~s("foobar")) == "foobar"
  end

  test "atom keys" do
    hash = :erlang.phash2(:crypto.strong_rand_bytes(8))

    assert_raise ParseError,
                 ~s(Cannot parse value at position 3: "key#{hash}"),
                 fn ->
                   parse!(~s({"key#{hash}": null}), %{keys: :atoms!})
                 end

    assert parse!(~s({"foo": "bar"}), %{keys: :atoms!}) == %{foo: "bar"}
    assert parse!(~s({"foo": "bar"}), %{keys: :atoms}) == %{foo: "bar"}
  end

  test "parse date" do
    date =
      %Date{
        calendar: Calendar.ISO,
        day: 10,
        month: 10,
        year: 2018
      }

    assert parse!("\"2018-10-10\"", %{format_datetime: :date}) == date
  end

  test "parse time" do
    time =
      %Time{
        calendar: Calendar.ISO,
        hour: 1,
        minute: 8,
        second: 52,
        microsecond: {735272, 6}
      }

    assert parse!("\"01:08:52.735272\"", %{format_datetime: :time}) == time
  end

  test "parse datetime" do
    datetime =
      %DateTime{
        calendar: Calendar.ISO,
        day: 11,
        hour: 0,
        microsecond: {262450, 6},
        minute: 12,
        month: 10,
        second: 41,
        std_offset: 0,
        time_zone: "Etc/UTC",
        utc_offset: 0,
        year: 2018,
        zone_abbr: "UTC"
      }

    assert parse!("\"2018-10-11T00:12:41.262450Z\"", %{format_datetime: :datetime}) == datetime
  end

  test "parse naive datetime" do
    naive_datetime =
      %NaiveDateTime{
        calendar: Calendar.ISO,
        day: 10,
        hour: 1,
        minute: 13,
        month: 10,
        second: 20,
        microsecond: {712433, 6},
        year: 2018
      }

    assert parse!("\"2018-10-10T01:13:20.712433\"", %{format_datetime: :naive_datetime}) == naive_datetime
  end


  defp parse!(iodata) do
    parse!(iodata, %{})
  end
end
