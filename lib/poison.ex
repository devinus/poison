defmodule Poison do
  @moduledoc """
  Main module for Poison Library to fast encode/decode json into elixir

  #### Usage

  Uses encode or decode to transform data.

      Poison.encode!(%{name: "Devin Torres", age:27})
      #=> "{\"name\":\"Devin Torres\",\"age\":27}"

      Poison.decode!(~s({"name":"Devin Torres","age":27}))
      #=> %{"age" => 27, "name" => "Devin Torres"}

  It's also possible to encode/eecode a struct directly

      defmodule Person do
        @derive [Poison.Encoder]
        defstruct [:name, :age]
      end

      Poison.encode!(%Person{name: "Devin Torres", age: 27})
      #=> "{\"name\":\"Devin Torres\",\"age\":27}"

      Poison.decode!(~s({"name": "Devin Torres", "age": 27}), as: %Person{})
      #=> %Person{name: "Devin Torres", age: 27}

      Poison.decode!(~s({"people": [{"name": "Devin Torres", "age": 27}]}),
        as: %{"people" => [%Person{}]})
      #=> %{"people" => [%Person{age: 27, name: "Devin Torres"}]}

  For maximum performance, make sure you `@derive [Poison.Encoder]`
  for any struct you plan on encoding.
  """

  alias Poison.Encoder
  alias Poison.Decode
  alias Poison.Parser

  @doc """
  Encodes an elixir value into a JSON.

  Any value that implements the `Poison.Encoder` protocol is sutiable to be encoded.

  ## Examples

      iex> Poison.encode([1, 2, 3])
      {:ok, "[1,2,3]"}
      iex> Poison.encode("Poison String")
      {:ok, ~s("Poison String")}
      iex> Poison.encode(%{name: "John Doe"})
      {:ok, ~s({"name":"John Doe"})}

  ## Options

    * `:pretty` - if true produces a pretty output for readability.
      Default is `false`
    * `:indent` - define the indentation spaces for the JSON. Only usable when
      `pretty` option is set to `true`. Default is `2`
    * `:iodata` - if true produces the output as iodata
    * `:strict_keys` - if is set to true returns an error if finds a duplicated
      key on a map
    * `:escape` - escape after converting to json possible parameters are:

      * `:unicode` - escape unicode characters into Backslash-U notation
      * `:javascript` - escape some javascript ilegal characters like `\u2028`
      * `:html_safe` - inhents behaviour form :javascript option and
        escape the data providing a html_safe json

  ## Return values

  If the encode is successful, returns a tuple with `{:ok, encoded_data}`,
  where `encoded_data` is the result of the encode. If the encode fails,
  this function returns a tuple with `{:error, {:invalid, invalid_value}}`,
  where `invalid_value` is the value that couldn't be encoded.
  """
  @spec encode(Encoder.t, Keyword.t) :: {:ok, iodata} | {:ok, String.t}
    | {:error, {:invalid, any}}
  def encode(value, options \\ []) do
    {:ok, encode!(value, options)}
  rescue
    exception in [Poison.EncodeError] ->
      {:error, {:invalid, exception.value}}
  end

  @doc """
  Encode a value to JSON as iodata. works like
  `Poison.encode` but returns an iodata

      iex> Poison.encode_to_iodata([1, 2, 3])
      {:ok, [91, ["1", 44, "2", 44, "3"], 93]}
  """
  @spec encode_to_iodata(Encoder.t, Keyword.t) :: {:ok, iodata}
    | {:error, {:invalid, any}}
  def encode_to_iodata(value, options \\ []) do
    encode(value, [iodata: true] ++ options)
  end

  @doc """
  Encode a value to JSON, like `Poison.encode`, but it raises
  an exception on error.

      iex> Poison.encode!([1, 2, 3])
      "[1,2,3]"
  """
  @spec encode!(Encoder.t, Keyword.t) :: iodata | no_return
  def encode!(value, options \\ []) do
    iodata = Encoder.encode(value, options)
    unless options[:iodata] do
      iodata |> IO.iodata_to_binary
    else
      iodata
    end
  end

  @doc """
  Encode a value to JSON as iodata, like `Poison.encode_to_iodata`,
  but raises an exception on error.

      iex> Poison.encode_to_iodata!([1, 2, 3])
      [91, ["1", 44, "2", 44, "3"], 93]
  """
  @spec encode_to_iodata!(Encoder.t, Keyword.t) :: iodata | no_return
  def encode_to_iodata!(value, options \\ []) do
    encode!(value, [iodata: true] ++ options)
  end

  @doc """
  Decode JSON to a value.

      iex> Poison.decode("[1,2,3]")
      {:ok, [1, 2, 3]}
  """
  @spec decode(iodata, Keyword.t) :: {:ok, Parser.t} | {:error, :invalid}
    | {:error, {:invalid, String.t}}
  def decode(iodata, options \\ []) do
    case Parser.parse(iodata, options) do
      {:ok, value} -> {:ok, Decode.decode(value, options)}
      error -> error
    end
  end

  @doc """
  Decode JSON to a value, raises an exception on error.

      iex> Poison.decode!("[1,2,3]")
      [1, 2, 3]
  """
  @spec decode!(iodata, Keyword.t) :: Parser.t | no_return
  def decode!(iodata, options \\ []) do
    Decode.decode(Parser.parse!(iodata, options), options)
  end
end
