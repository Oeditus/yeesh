defmodule Yeesh.Builtin.Help do
  @moduledoc false
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

  @impl true
  def execute([], session) do
    commands = Registry.list_all()

    output =
      Enum.map_join(commands, "\r\n", fn {cmd_name, module} ->
        padded = String.pad_trailing(cmd_name, 16)
        Output.green(padded) <> module.description()
      end)

    header = Output.bold("Available commands:") <> "\r\n\r\n"
    footer = "\r\n\r\n" <> Output.dim("Type 'help <command>' for detailed usage.")

    {:ok, header <> output <> footer, session}
  end

  def execute([cmd_name], session) do
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

  def execute(_args, session) do
    {:error, "usage: help [command]", session}
  end
end
