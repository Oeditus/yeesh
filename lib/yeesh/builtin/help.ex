defmodule Yeesh.Builtin.Help do
  @moduledoc """
  Built-in `help` command.

  When invoked without arguments, lists all registered commands grouped by
  name prefix:

    - Built-in commands (from `Yeesh.Registry.builtin_commands/0`) are
      grouped under **"Built-in"**.
    - Commands that implement the optional `c:Yeesh.Command.group/0`
      callback are grouped under the returned string (takes precedence
      over automatic grouping).
    - Consumer commands whose name contains no separator (`.`, `-`, `_`)
      are grouped under **"Generic"**.
    - Consumer commands with a separator are grouped by the text before
      the first separator, capitalized (e.g. `db.migrate` -> **"Db"**).

  Groups are sorted: Built-in first, Generic second, then custom groups
  alphabetically.

  When invoked with a command name (`help <command>`), shows its description
  and usage.
  """
  @behaviour Yeesh.Command

  alias Yeesh.{Output, Registry}

  @impl true
  def name, do: "help"

  @impl true
  def description, do: "Show available commands or help for a specific command"

  @impl true
  def usage, do: "help [command]"

  @impl true
  def completions(partial, _session) do
    Registry.completions_for(partial)
  end

  @separator_pattern ~r/[.\-_]/

  @impl true
  def execute([], session) do
    groups =
      Registry.list_all()
      |> Enum.group_by(&group_key/1)
      |> Enum.sort_by(fn {key, _} -> group_sort_key(key) end)

    output =
      Enum.map_join(groups, "\r\n\r\n", fn {group_name, commands} ->
        header = Output.bold(Output.underline(group_name))
        lines = format_commands(commands)
        header <> ":\r\n" <> lines
      end)

    footer = "\r\n\r\n" <> Output.dim("Type 'help <command>' for detailed usage.")

    {:ok, output <> footer, session}
  end

  def execute([_ | _] = args, session) do
    cmd_name = Enum.join(args, " ")

    case Registry.lookup(cmd_name) do
      {:ok, module} ->
        output =
          Output.bold(module.name()) <>
            " - " <>
            module.description() <>
            "\r\n\r\n" <>
            Output.dim("Usage: ") <> module.usage()

        {:ok, output, session}

      :error ->
        {:error, "unknown command: #{cmd_name}", session}
    end
  end

  defp group_key({_name, module}) do
    cond do
      builtin?(module) ->
        "Built-in"

      function_exported?(module, :group, 0) ->
        module.group()

      true ->
        case Regex.split(@separator_pattern, module.name(), parts: 2) do
          [_single] -> "Generic"
          [prefix | _] -> String.capitalize(prefix)
        end
    end
  end

  defp builtin?(module) do
    module in Registry.builtin_commands()
  end

  # Sort: "Built-in" first, "Generic" second, then alphabetical
  defp group_sort_key("Built-in"), do: {0, ""}
  defp group_sort_key("Generic"), do: {1, ""}
  defp group_sort_key(name), do: {2, name}

  defp format_commands(commands) do
    Enum.map_join(commands, "\r\n", fn {cmd_name, module} ->
      padded = String.pad_trailing(cmd_name, 16)
      "  " <> Output.green(padded) <> module.description()
    end)
  end
end
