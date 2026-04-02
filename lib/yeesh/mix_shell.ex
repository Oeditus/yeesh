if Code.ensure_loaded?(Mix.Shell) do
  defmodule Yeesh.MixShell do
    @moduledoc """
    Custom `Mix.Shell` implementation for Yeesh Mix task execution.

    Identical to `Mix.Shell.IO` except that `error/1` writes through
    `IO.puts/1` (which routes through the process group leader) instead
    of writing to `:standard_error` directly. This ensures error output
    from Mix tasks is captured by `Yeesh.IOServer` when the task's
    group leader has been replaced.

    For processes with a normal group leader, the behaviour is
    effectively identical to `Mix.Shell.IO` -- output goes to stdout
    through the default group leader.

    This module is only compiled when `Mix.Shell` is available (i.e.
    in dev/test environments, not in releases).
    """

    @behaviour Mix.Shell

    @impl true
    def info(message) do
      IO.puts(IO.ANSI.format(message))
    end

    @impl true
    def error(message) do
      # Route through group leader so IOServer captures it.
      # Original Mix.Shell.IO uses IO.puts(:standard_error, ...) which
      # bypasses the group leader and is invisible to IOServer.
      IO.puts(IO.ANSI.format([:red, to_string(message), :reset]))
    end

    @impl true
    def prompt(message) do
      IO.gets(message <> " ")
      |> to_string()
      |> String.trim_trailing()
    end

    @impl true
    def yes?(message, opts \\ []) do
      default = Keyword.get(opts, :default, :yes)
      suffix = yes_suffix(default)

      info(message)
      answer = IO.gets(suffix) |> to_string() |> String.trim() |> String.downcase()
      parse_yes_no(answer, default, message, opts)
    end

    defp yes_suffix(:yes), do: " [Yn] "
    defp yes_suffix(:no), do: " [yN] "
    defp yes_suffix(_), do: " [yn] "

    defp parse_yes_no("", default, _msg, _opts), do: default == :yes
    defp parse_yes_no(a, _default, _msg, _opts) when a in ["y", "yes"], do: true
    defp parse_yes_no(a, _default, _msg, _opts) when a in ["n", "no"], do: false
    defp parse_yes_no(_, _default, msg, opts), do: yes?(msg, opts)

    @impl true
    def cmd(command, opts \\ []) do
      # Delegating to the default shell for OS commands.
      # In a Yeesh IOServer context, stdout/stderr from the OS process
      # won't be captured, but the exit status is returned.
      Mix.Shell.cmd(command, opts, fn data -> IO.write(data) end)
    end

    @impl true
    def print_app do
      if name = Mix.Shell.printable_app_name() do
        IO.puts("==> #{name}")
      end
    end
  end
end
