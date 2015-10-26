defmodule Poison.Mixfile do
  use Mix.Project

  @version File.read!("VERSION") |> String.strip

  def project do
    [app: :poison,
     version: @version,
     elixir: "~> 1.0",
     description: "The fastest JSON library for Elixir",
     deps: deps,
     package: package]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: []]
  end

  # Dependencies can be hex.pm packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [{:decimal,   "~> 1.1"},
     {:earmark, "~> 0.1", only: :docs},
     {:ex_doc, "~> 0.7", only: :docs},
     {:jiffy, github: "davisp/jiffy", only: :bench},
     {:exjsx, github: "talentdeficit/exjsx", only: :bench},
     {:jazz, github: "meh/jazz", only: :bench}]
  end

  defp package do
    [files: ~w(lib mix.exs README.md LICENSE UNLICENSE VERSION),
     contributors: ["Devin Torres"],
     licenses: ["Unlicense"],
     links: %{"GitHub" => "https://github.com/devinus/poison"}]
  end
end
