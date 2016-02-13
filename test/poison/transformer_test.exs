defmodule Poison.TransformerTest do
  use ExUnit.Case, async: true

  test "Camel Case" do
    assert camelcase("foo") == "foo"
    assert camelcase("foo_bar") == "fooBar"
    assert camelcase("_foo") == "foo"
    assert camelcase("foo_") == "foo"
    assert camelcase("_foo_") == "foo"
    assert camelcase("_foo_bar") == "fooBar"
  end

  test "Snake Case" do
    assert snakecase("foo") == "foo"
    assert snakecase("fooBar") == "foo_bar"
    assert snakecase("fooBARBaz") == "foo_bar_baz"
  end

  def camelcase(s) do
    Poison.CamelCase.transform(s)
  end

  def snakecase(s) do
    Poison.SnakeCase.transform(s)
  end
end
