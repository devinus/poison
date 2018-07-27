defmodule Poison do
  @readme_path [__DIR__, "..", "README.md"] |> Path.join() |> Path.expand()
  @external_resource @readme_path
  @moduledoc @readme_path |> File.read!() |> String.trim()

  alias Poison.{Decode, DecodeError, Decoder}
  alias Poison.{EncodeError, Encoder}
  alias Poison.{ParseError, Parser}

  @doc """
  Encode a value to JSON.

      iex> Poison.encode([1, 2, 3])
      {:ok, "[1,2,3]"}
  """
  @spec encode(Encoder.t(), keyword | Encoder.options()) ::
          {:ok, iodata}
          | {:error, EncodeError.t()}
  def encode(value, options \\ %{}) do
    {:ok, encode!(value, options)}
  rescue
    exception in [EncodeError] ->
      {:error, exception}
  end

  @doc """
  Encode a value to JSON, raises an exception on error.

      iex> Poison.encode!([1, 2, 3])
      "[1,2,3]"
  """
  @spec encode!(Encoder.t(), keyword | Encoder.options()) :: iodata | no_return
  def encode!(value, options \\ %{})

  def encode!(value, options) when is_list(options) do
    encode!(value, Map.new(options))
  end

  def encode!(value, options) do
    iodata = Encoder.encode(value, options)

    if options[:iodata] do
      iodata
    else
      iodata |> IO.iodata_to_binary()
    end
  end

  @doc """
  Decode JSON to a value.

      iex> Poison.decode("[1,2,3]")
      {:ok, [1, 2, 3]}
  """
  @spec decode(iodata) ::
          {:ok, Parser.t()}
          | {:error, ParseError.t()}
  @spec decode(iodata, keyword | Decoder.options()) ::
          {:ok, any}
          | {:error, ParseError.t() | DecodeError.t()}
  def decode(iodata, options \\ %{}) do
    {:ok, decode!(iodata, options)}
  rescue
    exception in [ParseError, DecodeError] ->
      {:error, exception}
  end

  @doc """
  Decode JSON to a value, raises an exception on error.

      iex> Poison.decode!("[1,2,3]")
      [1, 2, 3]
  """
  @spec decode!(iodata) :: Parser.t() | no_return
  def decode!(value) do
    Parser.parse!(value, %{})
  end

  @spec decode!(iodata, keyword | Decoder.options()) :: Decoder.t() | no_return
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
