defmodule Yeesh.Builtin.Clear do
  @moduledoc false
  @behaviour Yeesh.Command

  @impl true
  def name, do: "clear"

  @impl true
  def description, do: "Clear the terminal screen"

  @impl true
  def usage, do: "clear"

  @impl true
  def execute(_args, session) do
    # Special escape sequence to clear screen + move cursor to top
    {:ok, "\e[2J\e[H", session}
  end
end
