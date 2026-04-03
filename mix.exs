defmodule Yeesh.MixProject do
  use Mix.Project

  @app :yeesh
  @version "0.3.0"
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
        plt_add_apps: [:mix, :ex_unit],
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
      {:mdex, "~> 0.11"},

      # Dev / Test
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
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
    """
  end

  defp package do
    [
      name: @app,
      files: ~w(
        lib
        assets
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
      logo: "stuff/img/logo-48x48.jpg",
      assets: %{"stuff/img" => "assets"},
      extras: ["README.md", "stuff/mix_tasks.md", "stuff/yeesh_markdown.md"],
      extra_section: "GUIDES",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html", "epub"],
      groups_for_modules: groups_for_modules(),
      nest_modules_by_prefix: [
        Yeesh.Builtin,
        Yeesh.Live
      ],
      authors: ["Aleksei Matiushkin"],
      canonical: "https://hexdocs.pm/#{@app}"
    ]
  end

  defp groups_for_modules do
    [
      Core: [
        Yeesh,
        Yeesh.Command,
        Yeesh.Executor,
        Yeesh.Session,
        Yeesh.Registry
      ],
      LiveView: [
        Yeesh.Live.TerminalComponent
      ],
      Sandbox: [
        Yeesh.Sandbox
      ],
      "Built-in Commands": [
        Yeesh.Builtin.Clear,
        Yeesh.Builtin.Echo,
        Yeesh.Builtin.ElixirEval,
        Yeesh.Builtin.Env,
        Yeesh.Builtin.Help,
        Yeesh.Builtin.History,
        Yeesh.Builtin.MixTask
      ],
      "Mix Integration": [
        Yeesh.IOServer,
        Yeesh.MixRunner,
        Yeesh.MixShell,
        Yeesh.MixCommand
      ],
      Utilities: [
        Yeesh.Completion,
        Yeesh.Markdown,
        Yeesh.Output
      ]
    ]
  end
end
