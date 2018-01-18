defmodule Poison.Mixfile do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim()

  def project do
    [
      app: :poison,
      version: @version,
      elixir: "~> 1.4",
      description: "An incredibly fast, pure Elixir JSON library",
      consolidate_protocols: Mix.env() not in [:dev, :test],
      deps: deps(),
      package: package(),
      dialyzer: [ignore_warnings: "dialyzer.ignore-warnings"]
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
      Keyword.put_new(spec, :applications, [])
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
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:benchee, "~> 0.11", only: :bench},
      {:benchee_json,
       github: "devinus/benchee_json", branch: "poison-optional", override: true, only: :bench},
      {:benchee_html, "~> 0.4", only: :bench},
      {:exjsx, "~> 4.0", only: :bench},
      {:tiny, "~> 1.0", only: :bench},
      {:jsone, "~> 1.4", only: :bench},
      {:jiffy, "~> 0.15", only: :bench},
      {:json, "~> 1.0", only: :bench}
    ]
  end

  defp package do
    [
      files: ~w(lib mix.exs README.md LICENSE VERSION),
      maintainers: ["Devin Torres"],
      licenses: ["CC0-1.0"],
      links: %{"GitHub" => "https://github.com/devinus/poison"}
    ]
  end
end
