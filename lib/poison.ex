defmodule Poison do
  readme_path = [__DIR__, "..", "README.md"] |> Path.join() |> Path.expand()

  @external_resource readme_path
  @moduledoc readme_path |> File.read!() |> String.trim()

  alias Poison.{Decode, DecodeError, Decoder}
  alias Poison.{EncodeError, Encoder}
  alias Poison.{ParseError, Parser}

  @doc """
  Encode a value to JSON.

      iex> Poison.encode([1, 2, 3])
      {:ok, "[1,2,3]"}
  """
  @spec encode(Encoder.t(), Encoder.options()) ::
          {:ok, iodata}
          | {:error, Exception.t()}
  def encode(value, options \\ %{}) do
    {:ok, encode!(value, options)}
  rescue
    exception in [EncodeError] ->
      {:error, exception}
  end

  @doc """
  Encode a value to JSON IO data.

      iex> Poison.encode_to_iodata([1, 2, 3])
      {:ok, [91, ["1", 44, "2", 44, "3"], 93]}
  """
  @spec encode_to_iodata(Encoder.t(), Encoder.options()) ::
          {:ok, iodata}
          | {:error, Exception.t()}
  def encode_to_iodata(value, options \\ %{}) do
    {:ok, encode_to_iodata!(value, options)}
  rescue
    exception in [EncodeError] ->
      {:error, exception}
  end

  @doc """
  Encode a value to JSON IO data. Raises an exception on error.

      iex> Poison.encode_to_iodata!([1, 2, 3])
      [91, ["1", 44, "2", 44, "3"], 93]
  """
  @spec encode_to_iodata!(Encoder.t(), Encoder.options()) :: iodata | no_return
  def encode_to_iodata!(value, options \\ %{})

  def encode_to_iodata!(value, options) when is_list(options) do
    encode_to_iodata!(value, Map.new(options))
  end

  def encode_to_iodata!(value, options) do
    Encoder.encode(value, options)
  end

  @doc """
  Encode a value to JSON. Raises an exception on error.

      iex> Poison.encode!([1, 2, 3])
      "[1,2,3]"
  """
  @spec encode!(Encoder.t(), Encoder.options()) :: binary | no_return
  def encode!(value, options \\ %{})

  def encode!(value, options) do
    value |> encode_to_iodata!(options) |> IO.iodata_to_binary()
  end

  @doc """
  Decode JSON to a value.

      iex> Poison.decode("[1,2,3]")
      {:ok, [1, 2, 3]}
  """
  @spec decode(iodata) ::
          {:ok, Parser.t()}
          | {:error, Exception.t()}
  @spec decode(iodata, Decoder.options()) ::
          {:ok, Parser.t()}
          | {:error, Exception.t()}
  def decode(iodata, options \\ %{}) do
    {:ok, decode!(iodata, options)}
  rescue
    exception in [ParseError, DecodeError] ->
      {:error, exception}
  end

  @doc """
  Decode JSON to a value. Raises an exception on error.

      iex> Poison.decode!("[1,2,3]")
      [1, 2, 3]
  """
  @spec decode!(iodata) :: Parser.t() | no_return
  def decode!(value) do
    Parser.parse!(value, %{})
  end

  @spec decode!(iodata, Decoder.options()) :: Decoder.t() | no_return
  def decode!(value, options) when is_list(options) do
    decode!(value, Map.new(options))
  end

  def decode!(value, %{as: as} = options) when as != nil do
    value
    |> Parser.parse!(options)
    |> Decode.transform(options)
    |> Decoder.decode(options)
  end

  def decode!(value, options) do
    Parser.parse!(value, options)
  end
end
