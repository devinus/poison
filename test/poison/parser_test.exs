defmodule Poison.ParserTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Poison.Parser
  alias Poison.ParseError

  test "numbers" do
    assert_raise ParseError, "unexpected end of input at position 1", fn ->
      parse!("-")
    end

    assert_raise ParseError, "unexpected token at position 1: -", fn ->
      parse!("--1")
    end

    assert_raise ParseError, "unexpected token at position 1: 1", fn ->
      parse!("01")
    end

    assert_raise ParseError, "unexpected token at position 0: .", fn ->
      parse!(".1")
    end

    assert_raise ParseError, "unexpected end of input at position 2", fn ->
      parse!("1.")
    end

    assert_raise ParseError, "unexpected end of input at position 2", fn ->
      parse!("1e")
    end

    assert_raise ParseError, "unexpected end of input at position 5", fn ->
      parse!("1.0e+")
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

    # credo:disable-for-next-line Credo.Check.Readability.LargeNumbers
    assert parse!("123456789.123456789e123") == 1.234567891234568e131

    assert parse!("0", %{decimal: true}) == Decimal.new("0")
    assert parse!("-0", %{decimal: true}) == Decimal.new("-0")
    assert parse!("99", %{decimal: true}) == Decimal.new("99")
    assert parse!("-99", %{decimal: true}) == Decimal.new("-99")
    assert parse!("99.99", %{decimal: true}) == Decimal.new("99.99")
    assert parse!("-99.99", %{decimal: true}) == Decimal.new("-99.99")
    assert parse!("99.99e99", %{decimal: true}) == Decimal.new("99.99e99")
    assert parse!("-99.99e99", %{decimal: true}) == Decimal.new("-99.99e99")
    assert parse!("-9.9999999999e9999999999", %{decimal: true}) == Decimal.new("-9.9999999999e9999999999")
  end

  property "number" do
    check all int <- integer() do
      assert parse!(Integer.to_string(int)) == int
    end

    check all value <- float() do
      assert parse!(Float.to_string(value)) == value
    end
  end

  test "strings" do
    assert_raise ParseError, "unexpected end of input at position 1", fn ->
      parse!(~s("))
    end

    assert_raise ParseError, "unexpected end of input at position 3", fn ->
      parse!(~s("\\"))
    end

    assert_raise ParseError, "unexpected token at position 2: k", fn ->
      parse!(~s("\\k"))
    end

    assert_raise ParseError, "unexpected end of input at position 9", fn ->
      parse!(~s("\\u2603\\"))
    end

    assert_raise ParseError, "unexpected end of input at position 39", fn ->
      parse!(~s("Here's a snowman for you: ☃. Good day!))
    end

    assert_raise ParseError, "unexpected end of input at position 2", fn ->
      parse!(~s("𝄞))
    end

    assert_raise ParseError, "unexpected token at position 0: á", fn ->
      parse!(~s(á))
    end

    assert_raise ParseError, "unexpected token at position 0: \\x1F", fn ->
      parse!(~s(\u001F))
    end

    assert_raise ParseError,
                 ~s(cannot parse value at position 8: "\\\\udcxx"),
                 fn ->
                   parse!(~s("\\ud8aa\\udcxx"))
                 end

    assert_raise ParseError,
                 ~s(cannot parse value at position 2: "\\\\uxxxx"),
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

  property "strings" do
    check all str <- string(:printable) do
      assert parse!(~s("#{str}")) == str
    end

    check all value <- member_of(Enum.concat(0x0..0xD7FF, 0xE000..0xFFFF)) do
      seq = value |> Integer.to_string(16) |> String.pad_leading(4, "0")
      assert parse!(~s("\\u#{seq}")) == <<value::utf8>>
    end

    check all hi <- integer(0xD800..0xDBFF),
              lo <- integer(0xDC00..0xDFFF) do
      seq1 = hi |> Integer.to_string(16) |> String.pad_leading(4, "0")
      seq2 = lo |> Integer.to_string(16) |> String.pad_leading(4, "0")
      <<codepoint::utf16>> = <<hi::16, lo::16>>

      expected = :unicode.characters_to_binary([codepoint], :utf16, :utf8)
      assert parse!(~s("\\u#{seq1}\\u#{seq2}")) == expected
    end
  end

  test "objects" do
    assert_raise ParseError, "unexpected end of input at position 1", fn ->
      parse!("{")
    end

    assert_raise ParseError, "unexpected token at position 1: ,", fn ->
      parse!("{,")
    end

    assert_raise ParseError, "unexpected token at position 6: }", fn ->
      parse!(~s({"foo"}))
    end

    assert_raise ParseError, "unexpected token at position 14: }", fn ->
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
    assert_raise ParseError, "unexpected end of input at position 1", fn ->
      parse!("[")
    end

    assert_raise ParseError, "unexpected token at position 1: ,", fn ->
      parse!("[,")
    end

    assert_raise ParseError, "unexpected token at position 3: ]", fn ->
      parse!("[1,]")
    end

    assert parse!("[]") == []
    assert parse!("[1, 2, 3]") == [1, 2, 3]
    assert parse!(~s(["foo", "bar", "baz"])) == ["foo", "bar", "baz"]
    assert parse!(~s([{"foo": "bar"}])) == [%{"foo" => "bar"}]
  end

  test "whitespace" do
    assert_raise ParseError, "unexpected end of input at position 0", fn ->
      parse!("")
    end

    assert_raise ParseError, "unexpected end of input at position 4", fn ->
      parse!("    ")
    end

    assert parse!("  [  ]  ") == []
    assert parse!("  {  }  ") == %{}

    assert parse!("  [  1  ,  2  ,  3  ]  ") == [1, 2, 3]

    expected = %{"foo" => "bar", "baz" => "quux"}

    assert parse!(~s(  {  "foo"  :  "bar"  ,  "baz"  :  "quux"  }  )) ==
             expected
  end

  test "atom keys" do
    hash = :erlang.phash2(:crypto.strong_rand_bytes(8))

    assert_raise ParseError,
                 ~s(cannot parse value at position 2: "key#{hash}"),
                 fn ->
                   parse!(~s({"key#{hash}": null}), %{keys: :atoms!})
                 end

    assert parse!(~s({"foo": "bar"}), %{keys: :atoms!}) == %{foo: "bar"}
    assert parse!(~s({"foo": "bar"}), %{keys: :atoms}) == %{foo: "bar"}
  end

  # See: https://github.com/lovasoa/bad_json_parsers
  test "deeply nested data structures" do
    path = Path.expand(Path.join(__DIR__, "../fixtures/unparsable.json"))
    data = File.read!(path)
    assert {:ok, _} = parse(data)
  end

  describe "JSONTestSuite" do
    root = Path.expand(Path.join(__DIR__, "../../vendor/JSONTestSuite/test_parsing"))

    for path <- Path.wildcard("#{root}/y_*.json") do
      file = Path.basename(path, ".json")

      test "#{file} passes" do
        data = File.read!(unquote(path))
        assert {:ok, _} = parse(data)
      end
    end

    for path <- Path.wildcard("#{root}/n_*.json") do
      file = Path.basename(path, ".json")

      test "#{file} fails" do
        data = File.read!(unquote(path))
        assert_raise ParseError, fn -> parse!(data) end
      end
    end
  end

  defp parse(iodata, options \\ %{}) do
    {:ok, parse!(iodata, options)}
  rescue
    exception ->
      {:error, exception}
  end
end
