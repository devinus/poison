defmodule PoisonTest do
  use ExUnit.Case

  import Poison
  alias Poison.SyntaxError

  test "numbers" do
    assert_raise SyntaxError, fn -> parse!("-") end
    assert_raise SyntaxError, fn -> parse!("01") end
  end
end
