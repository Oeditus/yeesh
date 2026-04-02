defmodule Mix.Tasks.YeeshTest.Echo do
  @shortdoc "Test task: echoes arguments"
  @moduledoc "Non-interactive Mix task for testing. Prints arguments to stdout."
  use Mix.Task

  @impl true
  def run(args) do
    IO.puts(Enum.join(args, " "))
  end
end
