defmodule Poison.Mixfile do
  use Mix.Project

  version_path = Path.join([__DIR__, "VERSION"])

  @external_resource version_path
  @version version_path |> File.read!() |> String.trim()

  def project do
    [
      app: :poison,
      name: "Poison",
      version: @version,
      elixir: "~> 1.11",
      description: "An incredibly fast, pure Elixir JSON library",
      source_url: "https://github.com/devinus/poison",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() not in [:dev, :test],
      elixirc_paths: elixirc_paths(),
      deps: deps(),
      docs: docs(),
      package: package(),
      aliases: aliases(),
      xref: [exclude: [Decimal]],
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
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
      {:benchee_html, "~> 1.0", only: :bench, runtime: false},
      {:benchee, "~> 1.0", only: :bench, runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:decimal, "~> 2.0", optional: true},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.25", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.14", only: :test, runtime: false},
      {:exjsx, "~> 4.0", only: [:bench, :profile], runtime: false},
      {:jason, "~> 1.2", only: [:dev, :test, :bench, :profile], runtime: false},
      {:jiffy, "~> 1.0", only: [:bench, :profile], runtime: false},
      {:json, "~> 1.4", only: [:bench, :profile], runtime: false},
      {:jsone, "~> 1.6", only: [:bench, :profile], runtime: false},
      {:junit_formatter, "~> 3.3", only: :test, runtime: false},
      {:stream_data, "~> 0.5", only: [:dev, :test], runtime: false},
      {:tiny, "~> 1.0", only: [:bench, :profile], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Poison",
      canonical: "https://hexdocs.pm/poison",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      files: ~w(lib mix.exs README.md LICENSE VERSION),
      maintainers: ["Devin Alexander Torres <d@devinus.io>"],
      licenses: ["0BSD"],
      links: %{"GitHub" => "https://github.com/devinus/poison"}
    ]
  end

  defp aliases do
    [
      "deps.get": [
        fn _ ->
          System.cmd("git", ["submodule", "update", "--init"], cd: __DIR__, parallelism: true)
        end,
        "deps.get"
      ]
    ]
  end
end
