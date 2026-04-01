defmodule Yeesh.MixProject do
  use Mix.Project

  @app :yeesh
  @version "0.1.0"
  @source_url "https://github.com/Oeditus/yeesh"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() not in [:dev, :test],
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_file: {:no_warn, ".dialyzer/dialyzer.plt"},
        plt_add_deps: :app_tree,
        plt_add_apps: [:mix],
        plt_core_path: ".dialyzer",
        list_unused_filters: true,
        ignore_warnings: ".dialyzer/ignore.exs"
      ],
      name: "Yeesh",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Yeesh.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.0"},
      {:jason, "~> 1.4"},
      {:dune, "~> 0.3"},

      # Dev / Test
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      quality: ["format", "credo --strict", "dialyzer"],
      "quality.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer"
      ]
    ]
  end

  defp description do
    """
    A LiveView terminal component with sandboxed command execution.
    Provides a browser-based CLI with fish/zsh-like features (tab completion,
    history, prompt customization) and Dune-powered sandboxed Elixir evaluation.
    Execution is synchronous in the current release; async streaming is planned
    for Milestone 3. OS command passthrough is planned for Milestone 2.
    """
  end

  defp package do
    [
      name: @app,
      files: ~w(
        lib
        assets
        priv
        .formatter.exs
        mix.exs
        README.md
        LICENSE
      ),
      licenses: ["MIT"],
      maintainers: ["Aleksei Matiushkin"],
      links: %{
        "GitHub" => @source_url,
        "Documentation" => "https://hexdocs.pm/#{@app}"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html", "epub"],
      extras: ["README.md"],
      authors: ["Aleksei Matiushkin"]
    ]
  end
end
