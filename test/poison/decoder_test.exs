defmodule Posion.DecoderTest do
  use ExUnit.Case

  import Poison.Decode

  defmodule Person do
    defstruct [:name, :age]
  end

  defimpl Poison.Decoder, for: Person do
    def decode(person, _options) do
      "#{person.name} (#{person.age})"
    end
  end

  test "decoding single :as with string keys" do
    person = %{"name" => "Devin Torres", "age" => 27}
    assert decode(person, as: Person) == "Devin Torres (27)"
  end

  test "decoding single :as with atom keys" do
    person = %{name: "Devin Torres", age: 27}
    assert decode(person, keys: :atoms!, as: Person) == "Devin Torres (27)"
  end

  test "decoding :as list with string keys" do
    person = [%{"name" => "Devin Torres", "age" => 27}]
    assert decode(person, as: [Person]) == ["Devin Torres (27)"]
  end

  test "decoding nested :as with string keys" do
    person = %{"person" => %{"name" => "Devin Torres", "age" => 27}}
    actual = decode(person, as: %{"person" => Person})
    expected = %{"person" => "Devin Torres (27)"}
    assert actual == expected
  end

  test "decoding nested :as with atom keys" do
    person = %{person: %{name: "Devin Torres", age: 27}}
    actual = decode(person, keys: :atoms!, as: %{person: Person})
    expected = %{person: "Devin Torres (27)"}
    assert actual == expected
  end

  test "decoding nested :as list with string keys" do
    people = %{"people" => [%{"name" => "Devin Torres", "age" => 27}]}
    actual = decode(people, as: %{"people" => [Person]})
    expected = %{"people" => ["Devin Torres (27)"]}
    assert actual == expected
  end
end
