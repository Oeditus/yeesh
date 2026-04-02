if Code.ensure_loaded?(Mix) do
  defmodule Yeesh.MixRunner do
    @moduledoc """
    Orchestrates running Mix tasks with I/O interception.

    Spawns a Mix task in a separate process whose group leader is a
    `Yeesh.IOServer`. This transparently captures all `IO.puts`/`IO.gets`
    calls from the task without requiring any modifications to the task
    itself.

    ## Return values

    `run/3` returns one of:

      * `{:interactive, io_server, task_pid, output, prompt}` -- the task
        called `IO.gets` and is waiting for input. Use
        `Yeesh.IOServer.provide_input_and_wait/3` to feed lines.
      * `{:completed, output}` -- the task finished without requesting input.
      * `{:error, reason}` -- the task could not be started.

    ## Example

        case Yeesh.MixRunner.run("my_app.status", ["--verbose"]) do
          {:completed, output} ->
            IO.puts(output)

          {:interactive, io_server, _pid, output, _prompt} ->
            IO.puts(output)
            {next_output, status, _} = Yeesh.IOServer.provide_input_and_wait(io_server, "hello")
            IO.puts(next_output)
        end
    """

    alias Yeesh.IOServer

    @typedoc "Result from starting a Mix task."
    @type run_result ::
            {:interactive, pid(), pid(), String.t(), String.t()}
            | {:completed, String.t()}
            | {:error, term()}

    @doc """
    Runs a Mix task with I/O interception.

    The task is spawned in a new process with a custom group leader
    (`Yeesh.IOServer`). `Mix.shell` is temporarily set to
    `Yeesh.MixShell` so that `Mix.shell().error/1` output is also
    captured.

    Uses `Mix.Task.rerun/2` to allow repeated execution of the same
    task within the VM.

    ## Options

      * `:timeout` -- how long to wait for the task to produce initial
        output or request input (default: 30000ms)
    """
    @spec run(String.t(), [String.t()], keyword()) :: run_result()
    def run(task_name, args \\ [], opts \\ []) do
      with :ok <- validate_task(task_name) do
        do_run(task_name, args, opts)
      end
    end

    defp validate_task(task_name) do
      case Mix.Task.get(task_name) do
        nil -> {:error, "unknown Mix task: #{task_name}"}
        _mod -> :ok
      end
    end

    defp do_run(task_name, args, opts) do
      {:ok, io_server} = IOServer.start_link()

      # Save and replace Mix.shell
      original_shell = Mix.shell()

      if Code.ensure_loaded?(Yeesh.MixShell) do
        Mix.shell(Yeesh.MixShell)
      end

      # Spawn the task process with our IOServer as group leader
      task_pid =
        spawn(fn ->
          Process.group_leader(self(), io_server)

          try do
            Mix.Task.rerun(task_name, args)
          rescue
            e ->
              IO.puts("Error running mix #{task_name}: #{Exception.message(e)}")
          end
        end)

      IOServer.monitor_task(io_server, task_pid)

      # Block until the task requests input or finishes
      result =
        case IOServer.start_and_wait(io_server, opts) do
          {output, :waiting, prompt} ->
            {:interactive, io_server, task_pid, output, prompt}

          {output, :done} ->
            cleanup(io_server, original_shell)
            {:completed, output}
        end

      # For non-interactive results, restore shell immediately.
      # For interactive tasks, shell is restored when the task finishes
      # (handled by the caller via Executor).
      result
    rescue
      e ->
        {:error, Exception.message(e)}
    end

    @doc """
    Cleans up after a Mix task finishes.

    Stops the IOServer and restores the original `Mix.shell`. Called
    automatically for non-interactive tasks; must be called by the
    `Yeesh.Executor` when an interactive task completes.
    """
    @spec cleanup(pid(), module()) :: :ok
    def cleanup(io_server, original_shell \\ Mix.Shell.IO) do
      if Process.alive?(io_server) do
        IOServer.stop(io_server)
      end

      Mix.shell(original_shell)
      :ok
    end
  end
end
