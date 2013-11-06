defmodule PoisonTest do
  use ExUnit.Case

  import Poison

  test "parses object literals" do
    parse("{}") == {}
  end
end
