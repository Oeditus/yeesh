if Code.ensure_loaded?(Mix) do
  defmodule Yeesh.Builtin.MixTask do
    @moduledoc """
    Built-in `mix` command for running Mix tasks from the Yeesh terminal.

    Supports both non-interactive tasks (which run to completion and return
    their output) and interactive tasks (which enter a REPL-like mode
    where each user input line is forwarded to the running task).

    ## Usage

        mix <task_name> [args...]

    ## Examples

        mix help                   # list available tasks
        mix deps.tree              # non-interactive, shows output
        mix ragex.chat             # interactive, enters mix_task mode
        mix ragex.chat --skip-analysis

    This module is only compiled when `Mix` is available (dev/test
    environments).
    """

    @behaviour Yeesh.Command

    alias Yeesh.{MixRunner, Output}

    @impl true
    def name, do: "mix"

    @impl true
    def description, do: "Run a Mix task (interactive or non-interactive)"

    @impl true
    def usage do
      "mix <task> [args...]  - run a Mix task\nmix                   - list available Mix tasks"
    end

    @impl true
    def completions(partial, _session) do
      Mix.Task.load_all()

      Mix.Task.all_modules()
      |> Enum.map(&Mix.Task.task_name/1)
      |> Enum.filter(&String.starts_with?(&1, partial))
      |> Enum.sort()
    end

    @impl true
    def execute([], session) do
      # No arguments: list available Mix tasks
      Mix.Task.load_all()

      tasks =
        Mix.Task.all_modules()
        |> Enum.map(fn mod ->
          name = Mix.Task.task_name(mod)
          shortdoc = Mix.Task.shortdoc(mod) || ""
          {name, shortdoc}
        end)
        |> Enum.sort_by(&elem(&1, 0))

      output =
        tasks
        |> Enum.map_join("\r\n", fn {name, doc} ->
          if doc == "" do
            Output.cyan(name)
          else
            Output.cyan(String.pad_trailing(name, 28)) <> Output.dim(doc)
          end
        end)

      header = Output.bold("Available Mix tasks:") <> "\r\n"
      {:ok, header <> output, session}
    end

    def execute([task_name | args], session) do
      case MixRunner.run(task_name, args) do
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
