defmodule Poison.ParserTest do
  use ExUnit.Case, async: true

  import Poison.Parser
  alias Poison.SyntaxError

  test "numbers" do
    assert_raise SyntaxError, "Unexpected end of input at position 1", fn -> parse!("-") end
    assert_raise SyntaxError, "Unexpected token at position 1: -", fn -> parse!("--1") end
    assert_raise SyntaxError, "Unexpected token at position 1: 1", fn -> parse!("01") end
    assert_raise SyntaxError, "Unexpected token at position 0: .", fn -> parse!(".1") end
    assert_raise SyntaxError, "Unexpected end of input at position 2", fn -> parse!("1.") end
    assert_raise SyntaxError, "Unexpected end of input at position 2", fn -> parse!("1e") end
    assert_raise SyntaxError, "Unexpected end of input at position 5", fn -> parse!("1.0e+") end
    assert_raise ArgumentError, "argument error", fn -> parse!("1.7976932e308") end

    # note: `parse` is also expected to raise an error in this case
    assert_raise ArgumentError, "argument error", fn -> parse("1.7976932e308") end

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
    assert parse!("123456789.123456789e123") == 123456789.123456789e123
    assert parse!("1.7976931e308") == 1.7976931e308
  end

  test "strings" do
    assert_raise SyntaxError, "Unexpected end of input at position 1", fn -> parse!(~s(")) end
    assert_raise SyntaxError, "Unexpected end of input at position 2", fn -> parse!(~s("\\")) end
    assert_raise SyntaxError, "Unexpected token at position 1: k", fn -> parse!(~s("\\k")) end
    assert_raise SyntaxError, "Unexpected end of input at position 1", fn -> parse!(<<34, 128, 34>>) end
    assert_raise SyntaxError, "Unexpected end of input at position 7", fn -> parse!(~s("\\u2603\\")) end
    assert_raise SyntaxError, "Unexpected end of input at position 39", fn -> parse!(~s("Here's a snowman for you: ☃. Good day!)) end
    assert_raise SyntaxError, "Unexpected end of input at position 2", fn -> parse!(~s("𝄞)) end

    assert parse!(~s("\\"\\\\\\/\\b\\f\\n\\r\\t")) == ~s("\\/\b\f\n\r\t)
    assert parse!(~s("\\u2603")) == "☃"
    assert parse!(~s("\\u2028\\u2029")) == "\u2028\u2029"
    assert parse!(~s("\\uD834\\uDD1E")) == "𝄞"
    assert parse!(~s("\\uD834\\uDD1E")) == "𝄞"
    assert parse!(~s("\\uD799\\uD799")) == "힙힙"
    assert parse!(~s("✔︎")) == "✔︎"
  end

  test "objects" do
    assert_raise SyntaxError, "Unexpected end of input at position 1", fn -> parse!("{") end
    assert_raise SyntaxError, "Unexpected token at position 1: ,", fn -> parse!("{,") end
    assert_raise SyntaxError, "Unexpected token at position 6: }", fn -> parse!(~s({"foo"})) end
    assert_raise SyntaxError, "Unexpected token at position 14: }", fn -> parse!(~s({"foo": "bar",})) end

    assert parse!("{}") == %{}
    assert parse!(~s({"foo": "bar"})) == %{"foo" => "bar"}

    expected = %{"foo" => "bar", "baz" => "quux"}
    assert parse!(~s({"foo": "bar", "baz": "quux"})) == expected

    expected = %{"foo" => %{"bar" => "baz"}}
    assert parse!(~s({"foo": {"bar": "baz"}})) == expected
  end

  test "arrays" do
    assert_raise SyntaxError, "Unexpected end of input at position 1", fn -> parse!("[") end
    assert_raise SyntaxError, "Unexpected token at position 1: ,", fn -> parse!("[,") end
    assert_raise SyntaxError, "Unexpected token at position 3: ]", fn -> parse!("[1,]") end

    assert parse!("[]") == []
    assert parse!("[1, 2, 3]") == [1, 2, 3]
    assert parse!(~s(["foo", "bar", "baz"])) == ["foo", "bar", "baz"]
    assert parse!(~s([{"foo": "bar"}])) == [%{"foo" => "bar"}]
  end

  test "whitespace" do
    assert_raise SyntaxError, "Unexpected end of input at position 0", fn -> parse!("") end
    assert_raise SyntaxError, "Unexpected end of input at position 4", fn -> parse!("    ") end

    assert parse!("  [  ]  ") == []
    assert parse!("  {  }  ") == %{}

    assert parse!("  [  1  ,  2  ,  3  ]  ") == [1, 2, 3]

    expected = %{"foo" => "bar", "baz" => "quux"}
    assert parse!(~s(  {  "foo"  :  "bar"  ,  "baz"  :  "quux"  }  )) == expected
  end

  test "atom keys" do
    hash = :erlang.phash2(:crypto.strong_rand_bytes(8))
    assert_raise ArgumentError, fn -> parse!(~s({"key#{hash}": null}), keys: :atoms!) end

    assert parse!(~s({"foo": "bar"}), keys: :atoms) == %{foo: "bar"}
    assert parse!(~s({"foo": "bar"}), keys: :atoms!) == %{foo: "bar"}
  end
end
