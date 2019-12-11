defmodule Poison.Mixfile do
  use Mix.Project

  version_path = Path.join([__DIR__, "VERSION"])

  @external_resource version_path
  @version version_path |> File.read!() |> String.trim()

  def project do
    [
      app: :poison,
      version: @version,
      elixir: "~> 1.8",
      description: "An incredibly fast, pure Elixir JSON library",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: not (Mix.env() in [:dev, :test]),
      elixirc_paths: elixirc_paths(),
      deps: deps(),
      package: package(),
      dialyzer: [
        ignore_warnings: "dialyzer.ignore-warnings",
        plt_add_apps: [:decimal],
        flags: [
          :error_handling,
          :race_conditions,
          :underspecs,
          :unmatched_returns
        ]
      ],
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

  # Run "mix help compile.app" to learn about applications.
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    spec = [extra_applications: []]

    if Mix.env() != :bench do
      spec
    else
      Keyword.put_new(spec, :applications, [:logger])
    end
  end

  defp elixirc_paths() do
    if Mix.env() == :profile do
      ["lib", "profile"]
    else
      ["lib"]
    end
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:decimal, "~> 1.8", optional: true},
      {:dialyxir, "~> 1.0.0-rc", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12", only: :test},
      {:benchee, "~> 1.0", only: :bench},
      {:benchee_json, "~> 1.0", only: :bench},
      {:benchee_html, "~> 1.0", only: :bench},
      {:exjsx, "~> 4.0", only: [:test, :bench, :profile]},
      {:jason, "~> 1.1", only: [:test, :bench, :profile]},
      {:jiffy, "~> 1.0", only: [:test, :bench, :profile]},
      {:json, "~> 1.3", only: [:test, :bench, :profile]},
      {:jsone, "~> 1.5", only: [:test, :bench, :profile]}
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
