defmodule Poison do
  alias Poison.Encoder
  alias Poison.Decoder
  alias Poison.Parser

  @spec encode(Encoder.t) :: { :ok, String.t } | { :error, any }
  def encode(value, options \\ []) do
    { :ok, encode!(value, options) }
  rescue
    exception ->
      { :error, Exception.message(exception) }
  end

  @spec encode(Encoder.t) :: String.t | no_return
  def encode!(value, options \\ []) do
    iodata_to_binary(Encoder.encode(value, options))
  end

  @spec decode(String.t) :: { :ok, Parser.t } | { :error, :invalid }
    | { :error, :invalid, String.t }
  def decode(string, options \\ []) do
    case Parser.parse(string, options) do
      { :ok, value } -> { :ok, Decoder.decode(value, options) }
      error -> error
    end
  end

  @spec decode!(iodata) :: Parser.t | no_return
  def decode!(string, options \\ []) do
    Decoder.decode(Parser.parse!(string, options), options)
  end
end
