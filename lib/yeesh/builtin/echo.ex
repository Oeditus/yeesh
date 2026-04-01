defmodule Yeesh.Builtin.Echo do
  @moduledoc false
  @behaviour Yeesh.Command

  @impl true
  def name, do: "echo"

  @impl true
  def description, do: "Print arguments to the terminal"

  @impl true
  def usage, do: "echo [text...]"

  @impl true
  def execute(args, session) do
    {:ok, Enum.join(args, " "), session}
  end
end
