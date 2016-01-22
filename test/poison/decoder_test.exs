defmodule Poison.DecoderTest do
  use ExUnit.Case, async: true

  import Poison.Decode

  defmodule Person do
    defstruct [:name, :address, :contact, age: 42]
  end

  defmodule Contact do
    defstruct [:email, :telephone]
  end

  defmodule Address do
    defstruct [:street, :city, :state, :zip]
  end

  defimpl Poison.Decoder, for: Address do
    def decode(address, _options) do
      "#{address.street}, #{address.city}, #{address.state}  #{address.zip}"
    end
  end

  test "decoding single :as with string keys" do
    person = %{"name" => "Devin Torres", "age" => 27}
    assert decode(person, as: %Person{}) == %Person{name: "Devin Torres", age: 27}
  end

  test "decoding single :as with atom keys" do
    person = %{name: "Devin Torres", age: 27}
    assert decode(person, keys: :atoms!, as: %Person{}) == %Person{name: "Devin Torres", age: 27}
  end

  test "decoding :as list with string keys" do
    person = [%{"name" => "Devin Torres", "age" => 27}]
    assert decode(person, as: [%Person{}]) == [%Person{name: "Devin Torres", age: 27}]
  end

  test "decoding nested :as with string keys" do
    person = %{"person" => %{"name" => "Devin Torres", "age" => 27}}
    actual = decode(person, as: %{"person" => %Person{}})
    expected = %{"person" => %Person{name: "Devin Torres", age: 27}}
    assert actual == expected
  end

  test "decoding nested :as with atom keys" do
    person = %{person: %{name: "Devin Torres", age: 27}}
    actual = decode(person, keys: :atoms!, as: %{person: %Person{}})
    expected = %{person: %Person{name: "Devin Torres", age: 27}}
    assert actual == expected
  end

  test "decoding nested :as list with string keys" do
    people = %{"people" => [%{"name" => "Devin Torres", "age" => 27}]}
    actual = decode(people, as: %{"people" => [%Person{}]})
    expected = %{"people" => [%Person{name: "Devin Torres", age: 27}]}
    assert actual == expected
  end

  test "decoding into nested structs" do
    person = %{"name" => "Devin Torres", "contact" => %{"email" => "devin@torres.com"}}
    assert decode(person, as: %Person{contact: %Contact{}}) == %Person{name: "Devin Torres", contact: %Contact{email: "devin@torres.com"}}
  end

  test "decoding into structs with key subset" do
    person = %{"name" => "Devin Torres", "age" => 27, "dob" => "1987-01-29"}
    assert decode(person, as: %Person{}) == %Person{name: "Devin Torres", age: 27}
  end

  test "decoding into structs with default values" do
    person = %{"name" => "Devin Torres"}
    assert decode(person, as: %Person{age: 50}) == %Person{name: "Devin Torres", age: 50}
  end

  test "decoding into structs with nil overriding defaults" do
    person = %{"name" => "Devin Torres", "age" => nil}
    assert decode(person, as: %Person{}) == %Person{name: "Devin Torres", age: nil}
  end

  test "decoding into nested structs with nil overriding defaults" do
    person = %{"name" => "Devin Torres", "address" => nil}
    assert decode(person, as: %Person{address: %Address{}}) == %Person{name: "Devin Torres", address: nil}
  end

  test "decoding using a defined decoder" do
    address = %{"street" => "1 Main St.", "city" => "Austin", "state" => "TX", "zip" => "78701"}
    assert decode(address, as: %Address{}) == "1 Main St., Austin, TX  78701"
  end
end
