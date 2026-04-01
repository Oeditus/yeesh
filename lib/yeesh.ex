defmodule Yeesh do
  @moduledoc """
  A LiveView terminal component with sandboxed command execution.

  Yeesh provides a browser-based CLI with fish/zsh-like features and
  Dune-powered sandboxed Elixir evaluation.

  ## Quick Start

  Add `yeesh` to your dependencies, then use the terminal component
  in any LiveView:

      <.live_component
        module={Yeesh.Live.TerminalComponent}
        id="terminal"
        commands={[MyApp.Commands.Deploy, MyApp.Commands.Status]}
      />

  ## Custom Commands

  Implement the `Yeesh.Command` behaviour:

      defmodule MyApp.Commands.Greet do
        @behaviour Yeesh.Command

        @impl true
        def name, do: "greet"

        @impl true
        def description, do: "Greet a user"

        @impl true
        def usage, do: "greet <name>"

        @impl true
        def completions(_partial, _session), do: []

        @impl true
        def execute(args, session) do
          name = Enum.join(args, " ")
          {:ok, "Hello, \#{name}!", session}
        end
      end

  ## Execution Model

  Command execution is currently synchronous -- the LiveView process blocks
  until the command completes (with a configurable timeout, default 5s).

  Async streaming execution is planned for Milestone 3.

  ## OS Command Passthrough

  OS command passthrough is planned for Milestone 2 and is not included
  in the current release. All commands must be explicitly registered
  via the `Yeesh.Command` behaviour.
  """

  @doc """
  Returns the default configuration for Yeesh.
  """
  @spec default_config :: keyword()
  def default_config do
    [
      prompt: "$ ",
      history_max_size: 1000,
      command_timeout: 5_000,
      max_output_size: 100_000,
      sandbox_opts: [],
      theme: :default
    ]
  end

  @doc """
  Merges user config with defaults.
  """
  @spec config(keyword()) :: keyword()
  def config(overrides \\ []) do
    Keyword.merge(default_config(), overrides)
  end
end
