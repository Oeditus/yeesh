if Code.ensure_loaded?(Mix) do
  defmodule Yeesh.MixCommand do
    @moduledoc """
    Generates a `Yeesh.Command` module that wraps a specific Mix task.

    Use this macro when you want to expose a Mix task as a named
    Yeesh terminal command, without requiring the user to type `mix`
    as a prefix.

    ## Usage

        defmodule MyApp.YeeshCommands.Chat do
          use Yeesh.MixCommand,
            task: "ragex.chat",
            name: "chat",
            description: "Interactive codebase Q&A",
            default_args: ["--skip-analysis"]
        end

    Then register it on the terminal component:

        <.live_component
          module={Yeesh.Live.TerminalComponent}
          id="terminal"
          commands={[MyApp.YeeshCommands.Chat]}
        />

    ## Options

      * `:task` (required) -- the Mix task name (e.g. `"ragex.chat"`)
      * `:name` (required) -- the command name in the Yeesh terminal
      * `:description` -- short description for `help` output
        (default: `"Run mix <task>"`)
      * `:usage` -- usage string (default: auto-generated from name and task)
      * `:default_args` -- default arguments prepended to user args
        (default: `[]`)

    The generated module delegates to `Yeesh.MixRunner.run/3` with
    the configured task name. User arguments are appended after
    `:default_args`. Interactive and non-interactive tasks are handled
    automatically.

    This module is only compiled when `Mix` is available.
    """

    @doc false
    defmacro __using__(opts) do
      task = Keyword.fetch!(opts, :task)
      cmd_name = Keyword.fetch!(opts, :name)
      desc = Keyword.get(opts, :description, "Run mix #{task}")
      usage = Keyword.get(opts, :usage, "#{cmd_name} [args...]")
      default_args = Keyword.get(opts, :default_args, [])

      quote do
        @behaviour Yeesh.Command

        alias Yeesh.{MixRunner, Output}

        @mix_task unquote(task)
        @cmd_name unquote(cmd_name)
        @cmd_desc unquote(desc)
        @cmd_usage unquote(usage)
        @default_args unquote(default_args)

        @impl true
        def name, do: @cmd_name

        @impl true
        def description, do: @cmd_desc

        @impl true
        def usage, do: @cmd_usage

        @impl true
        def execute(args, session) do
          full_args = @default_args ++ args

          case MixRunner.run(@mix_task, full_args) do
            {:completed, output} ->
              {:ok, output, session}

            {:interactive, io_server, task_pid, output, prompt} ->
              new_session = %{
                session
                | mode: :mix_task,
                  context:
                    Map.merge(session.context, %{
                      mix_io_server: io_server,
                      mix_task_pid: task_pid,
                      mix_prompt: prompt,
                      mix_original_shell: Mix.shell()
                    })
              }

              {:ok, output, new_session}

            {:error, reason} ->
              {:error, to_string(reason), session}
          end
        end
      end
    end
  end
end
