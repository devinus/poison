defmodule Poison do
  alias Poison.Encoder
  alias Poison.Decode
  alias Poison.Parser

  @doc """
  Encode a value to JSON.

  iex> Poison.encode([1, 2, 3])
  {:ok, [91, "1", [44, "2", 44, "3"], 93]}
  iex> Poison.encode([1, 2, 3], string: true)
  {:ok, "[1,2,3]"}
  """
  @spec encode(Encoder.t, Keyword.t) :: {:ok, iodata} | {:ok, String.t}
    | {:error, {:invalid, any}}
  def encode(value, options \\ []) do
    {:ok, encode!(value, options)}
  rescue
    exception in [Poison.EncodeError] ->
      {:error, {:invalid,  exception.value}}
  end

  @doc """
  Encode a value to JSON, raises an exception on error.

  iex> Poison.encode!([1, 2, 3])
  [91, "1", [44, "2", 44, "3"], 93]
  iex> Poison.encode!([1, 2, 3], string: true)
  "[1,2,3]"
  """
  @spec encode!(Encoder.t, Keyword.t) :: iodata | no_return
  def encode!(value, options \\ []) do
    iodata = Encoder.encode(value, options)
    if options[:string] do
      iodata |> IO.iodata_to_binary
    else
      iodata
    end
  end

  @doc """
  Decode JSON to a value.

  iex> Poison.decode("[1,2,3]")
  {:ok, [1, 2, 3]}
  """
  @spec decode(iodata) :: {:ok, Parser.t} | {:error, :invalid}
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
