defmodule Poison.Mixfile do
  use Mix.Project

  @version_path Path.join([__DIR__, "VERSION"])
  @external_resource @version_path
  @version @version_path |> File.read!() |> String.trim()

  def project do
    [
      app: :poison,
      version: @version,
      elixir: "~> 1.6",
      description: "An incredibly fast, pure Elixir JSON library",
      consolidate_protocols: not (Mix.env() in [:dev, :test]),
      deps: deps(),
      package: package(),
      dialyzer: [ignore_warnings: "dialyzer.ignore-warnings"],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.post": :test,
        "coveralls.travis": :test
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    spec = [extra_applications: []]

    if Mix.env() != :bench do
      spec
    else
      Keyword.put_new(spec, :applications, [:logger])
    end
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:dialyxir, "~> 0.5", only: :dev, runtime: false},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:excoveralls, "~> 0.9", only: :test},
      {:benchee, "~> 0.13", only: :bench},
      {:benchee_json, "~> 0.5", only: :bench},
      {:benchee_html, "~> 0.5", only: :bench},
      {:jason, "~> 1.1", only: [:test, :bench]},
      {:exjsx, "~> 4.0", only: :bench},
      {:tiny, "~> 1.0", only: :bench},
      {:jsone, "~> 1.4", only: :bench},
      {:jiffy, "~> 0.15", only: :bench},
      {:json, "~> 1.2", only: :bench}
    ]
  end

  defp package do
    [
      files: ~w(lib mix.exs README.md LICENSE VERSION),
      maintainers: ["Devin Alexander Torres"],
      licenses: ["CC0-1.0"],
      links: %{"GitHub" => "https://github.com/devinus/poison"}
    ]
  end
end
