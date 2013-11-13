defmodule PoisonTest do
  use ExUnit.Case

  import Poison
  alias Poison.SyntaxError

  test "numbers" do
    assert_raise SyntaxError, fn -> parse!("-") end
    assert_raise SyntaxError, fn -> parse!("01") end
    assert_raise SyntaxError, fn -> parse!("1e") end

    assert parse!("0") == 0
    assert parse!("1") == 1
    assert parse!("-0") == 0
    assert parse!("-1") == -1
    assert parse!("0.1") == 0.1
    assert parse!("-0.1") == -0.1
    assert parse!("0.1e1") == 0.1e1
    assert parse!("0.1e-1") == 0.1e-1
    assert parse!("99.99e99") == 99.99e99
    assert parse!("-99.99e-99") == -99.99e-99
    assert parse!("123456789.123456789e123") == 123456789.123456789e123
  end

  test "strings" do
  	assert parse!(%s{"\\u2028\\u2029"}) == "\x{2028}\x{2029}"
  end
end
