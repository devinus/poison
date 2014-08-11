defmodule Poison do
  alias Poison.Encoder
  alias Poison.Decode
  alias Poison.Parser

  @spec encode(Encoder.t) :: {:ok, iodata} | {:error, {:invalid, any}}
  def encode(value, options \\ []) do
    {:ok, encode!(value, options)}
  rescue
    exception in [Poison.EncodeError] ->
      {:error, {:invalid,  exception.value}}
  end

  @spec encode(Encoder.t) :: iodata
  def encode!(value, options \\ []) do
    Encoder.encode(value, options)
  end

  @spec decode(iodata) :: {:ok, Parser.t} | {:error, :invalid}
    | {:error, {:invalid, String.t}}
  def decode(iodata, options \\ []) do
    case Parser.parse(iodata, options) do
      {:ok, value} -> {:ok, Decode.decode(value, options)}
      error -> error
    end
  end

  @spec decode!(iodata) :: Parser.t
  def decode!(iodata, options \\ []) do
    Decode.decode(Parser.parse!(iodata, options), options)
  end
end
