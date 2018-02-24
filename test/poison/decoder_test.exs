defmodule Poison.DecoderTest do
  use ExUnit.Case, async: true

  import Poison.Decode, only: [transform: 2]

  defmodule Person do
    defstruct [:name, :address, :contact, age: 42]
  end

  defmodule Contact do
    defstruct [:email, :telephone]
  end

  defmodule Address do
    defstruct [:street, :city, :state, :zip]
  end

  defmodule Person2 do
   defstruct name: nil, age: 42, contacts: []
  end

  defmodule Contact2 do
    defstruct [:email, :telephone, call_count: 0]
  end

  defimpl Poison.Decoder, for: Address do
    def decode(address, _options) do
      "#{address.street}, #{address.city}, #{address.state}  #{address.zip}"
    end
  end

  defimpl Poison.Decoder.Remap, for: Contact2 do
    def remap( _as, contact, keys ) when keys in [ :atoms, :atoms! ], do: contact
    def remap( _as, contact, _keys ) do
      Map.new( contact, fn { k, v } -> { Macro.underscore( k ), v } end )
    end
  end

  test "decoding single :as with string keys" do
    person = %{"name" => "Devin Torres", "age" => 27}
    assert transform(person, %{as: %Person{}}) == %Person{name: "Devin Torres", age: 27}
  end

  test "decoding single :as with atom keys" do
    person = %{name: "Devin Torres", age: 27}
    assert transform(person, %{keys: :atoms!, as: %Person{}}) == %Person{name: "Devin Torres", age: 27}
  end

  test "decoding :as list with string keys" do
    person = [%{"name" => "Devin Torres", "age" => 27}]
    assert transform(person, %{as: [%Person{}]}) == [%Person{name: "Devin Torres", age: 27}]
  end

  test "decoding nested :as with string keys" do
    person = %{"person" => %{"name" => "Devin Torres", "age" => 27}}
    actual = transform(person, %{as: %{"person" => %Person{}}})
    expected = %{"person" => %Person{name: "Devin Torres", age: 27}}
    assert actual == expected
  end

  test "decoding nested :as with atom keys" do
    person = %{person: %{name: "Devin Torres", age: 27}}
    actual = transform(person, %{keys: :atoms!, as: %{person: %Person{}}})
    expected = %{person: %Person{name: "Devin Torres", age: 27}}
    assert actual == expected
  end

  test "decoding nested :as list with string keys" do
    people = %{"people" => [%{"name" => "Devin Torres", "age" => 27}]}
    actual = transform(people, %{as: %{"people" => [%Person{}]}})
    expected = %{"people" => [%Person{name: "Devin Torres", age: 27}]}
    assert actual == expected
  end

  test "decoding into structs with key subset" do
    person = %{"name" => "Devin Torres", "age" => 27, "dob" => "1987-01-29"}
    assert transform(person, %{as: %Person{}}) == %Person{name: "Devin Torres", age: 27}
  end

  test "decoding into structs with default values" do
    person = %{"name" => "Devin Torres"}
    assert transform(person, %{as: %Person{age: 50}}) == %Person{name: "Devin Torres", age: 50}
  end

  test "decoding into structs with unspecified default values" do
    person = %{"name" => "Devin Torres"}
    assert transform(person, %{as: %Person{}}) == %Person{name: "Devin Torres", age: 42}
  end

  test "decoding into structs with unspecified default values and atom keys" do
    person = %{:name => "Devin Torres"}
    assert transform(person, %{as: %Person{}, keys: :atoms!}) == %Person{name: "Devin Torres", age: 42}
  end

  test "decoding into structs with nil overriding defaults" do
    person = %{"name" => "Devin Torres", "age" => nil}
    assert transform(person, %{as: %Person{}}) == %Person{name: "Devin Torres", age: nil}
  end

  test "decoding into nested structs" do
    person = %{"name" => "Devin Torres", "contact" => %{"email" => "devin@torres.com"}}
    assert transform(person, %{as: %Person{contact: %Contact{}}}) == %Person{name: "Devin Torres", contact: %Contact{email: "devin@torres.com"}}
  end

  test "decoding into nested struct, empty nested struct" do
    person = %{"name" => "Devin Torres"}
    assert transform(person, %{as: %Person{contact: %Contact{}}}) == %Person{name: "Devin Torres"}
  end

  test "decoding into nested struct list" do
    person = %{"name" => "Devin Torres", "contacts" => [%{"email" => "devin@torres.com", "call_count" => 10}, %{"email" => "test@email.com"}]}
    expected = %Person2{
      name: "Devin Torres",
      contacts: [
        %Contact2{email: "devin@torres.com", call_count: 10},
        %Contact2{email: "test@email.com", call_count: 0}
      ]}

    decoded = transform(person, %{as: %Person2{contacts: [%Contact2{}]}})
    assert decoded == expected
  end

  test "decoding into nested struct list with keys = :atoms" do
    person = %{name: "Devin Torres", contacts: [%{email: "devin@torres.com", call_count: 10}, %{email: "test@email.com"}]}
    expected = %Person2{
      name: "Devin Torres",
      contacts: [
        %Contact2{email: "devin@torres.com", call_count: 10},
        %Contact2{email: "test@email.com", call_count: 0}
      ]}

    decoded = transform(person, %{as: %Person2{contacts: [%Contact2{}]}, keys: :atoms})
    assert decoded == expected
  end

  test "decoding into nested structs, empty list" do
    person = %{"name" => "Devin Torres"}

    expected = %Person2{
      name: "Devin Torres",
      contacts: []
    }

    assert transform(person, %{as: %Person2{contacts: [%Contact{}]}}) == expected
  end

  test "decoding into nested structs list with nil overriding default" do
    person = %{"name" => "Devin Torres", "contacts" => nil}
    assert transform(person, %{as: %Person2{contacts: [%Contact{}]}}) == %Person2{name: "Devin Torres", contacts: nil}
  end

  test "decoding into nested structs with nil overriding defaults" do
    person = %{"name" => "Devin Torres", "contact" => nil}
    assert transform(person, %{as: %Person{contact: %Contact{}}}) == %Person{name: "Devin Torres", contact: nil}
  end

  test "decoding using a defined decoder" do
    address = %{"street" => "1 Main St.", "city" => "Austin", "state" => "TX", "zip" => "78701"}
    assert transform(address, %{as: %Address{}}) == "1 Main St., Austin, TX  78701"
  end

  test "decoding using remapping with camel case string keys" do
    contact2 = %{ "callCount" => 7, "email" => "abc@123" }
    assert transform(contact2, %{as: %Contact2{}}) == %Poison.DecoderTest.Contact2{ call_count: 7, email: "abc@123" }
  end

  test "decoding using remapping with camel case atom keys" do
    contact2 = %{ :callCount => 7, :email => "abc@123" }
    assert transform(contact2, %{as: %Contact2{}, keys: :atoms}) == %Poison.DecoderTest.Contact2{ call_count: 0, email: "abc@123" }
  end
end
