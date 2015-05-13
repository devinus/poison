defmodule Poison.ParserTest do
  use ExUnit.Case, async: true

  import Poison.Parser
  alias Poison.SyntaxError

  test "numbers" do
    assert_raise SyntaxError, fn -> parse!("-") end
    assert_raise SyntaxError, fn -> parse!("--1") end
    assert_raise SyntaxError, fn -> parse!("01") end
    assert_raise SyntaxError, fn -> parse!(".1") end
    assert_raise SyntaxError, fn -> parse!("1.") end
    assert_raise SyntaxError, fn -> parse!("1e") end

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
  end

  test "strings" do
    assert_raise SyntaxError, fn -> parse!(~s(")) end
    assert_raise SyntaxError, fn -> parse!(~s("\\")) end
    assert_raise SyntaxError, fn -> parse!(~s("\\k")) end

    assert parse!(~s("\\"\\\\\\/\\b\\f\\n\\r\\t")) == ~s("\\/\b\f\n\r\t)
    assert parse!(~s("\\u2603")) == "☃"
    assert parse!(~s("\\u2028\\u2029")) == "\x{2028}\x{2029}"
    assert parse!(~s("\\uD834\\uDD1E")) == "𝄞"
    assert parse!(~s("\\uD834\\uDD1E")) == "𝄞"
    assert parse!(~s("\\uD799\\uD799")) == "힙힙"
    assert parse!(~s("✔︎")) == "✔︎"
  end

  test "objects" do
    assert_raise SyntaxError, fn -> parse!("{") end
    assert_raise SyntaxError, fn -> parse!("{,") end
    assert_raise SyntaxError, fn -> parse!(~s({"foo"})) end
    assert_raise SyntaxError, fn -> parse!(~s({"foo": "bar",})) end

    assert parse!("{}") == %{}
    assert parse!(~s({"foo": "bar"})) == %{"foo" => "bar"}

    expected = %{"foo" => "bar", "baz" => "quux"}
    assert parse!(~s({"foo": "bar", "baz": "quux"})) == expected

    expected = %{"foo" => %{"bar" => "baz"}}
    assert parse!(~s({"foo": {"bar": "baz"}})) == expected
  end

  test "arrays" do
    assert_raise SyntaxError, fn -> parse!("[") end
    assert_raise SyntaxError, fn -> parse!("[,") end
    assert_raise SyntaxError, fn -> parse!("[1,]") end

    assert parse!("[]") == []
    assert parse!("[1, 2, 3]") == [1, 2, 3]
    assert parse!(~s(["foo", "bar", "baz"])) == ["foo", "bar", "baz"]
    assert parse!(~s([{"foo": "bar"}])) == [%{"foo" => "bar"}]
  end

  test "whitespace" do
    assert_raise SyntaxError, fn -> parse!("") end
    assert_raise SyntaxError, fn -> parse!("    ") end

    assert parse!("  [  ]  ") == []
    assert parse!("  {  }  ") == %{}

    assert parse!("  [  1  ,  2  ,  3  ]  ") == [1, 2, 3]

    expected = %{"foo" => "bar", "baz" => "quux"}
    assert parse!(~s(  {  "foo"  :  "bar"  ,  "baz"  :  "quux"  }  )) == expected
  end

  test "atom keys" do
    hash = :erlang.phash2(:crypto.rand_bytes(8))
    assert_raise ArgumentError, fn -> parse!(~s({"key#{hash}": null}), keys: :atoms!) end

    assert parse!(~s({"foo": "bar"}), keys: :atoms) == %{foo: "bar"}
    assert parse!(~s({"foo": "bar"}), keys: :atoms!) == %{foo: "bar"}
  end
  
  test "argument errors" do
    assert parse(1) == {:error, :argument}
    assert parse(1.0) == {:error, :argument}
    assert parse(true) == {:error, :argument}
    assert parse(:hello) == {:error, :argument}
    assert parse(%{}) == {:error, :argument}
    assert parse({}) == {:error, :argument}
    assert parse(&(&1)) == {:error, :argument}
  end
end
