defmodule Mix.Tasks.YeeshTest.MultiOutput do
  @shortdoc "Test task: multiple output lines"
  @moduledoc "Non-interactive task that produces multiple lines of output."
  use Mix.Task

  @impl true
  def run(args) do
    count = if args == [], do: 3, else: String.to_integer(hd(args))

    for i <- 1..count do
      IO.puts("line #{i}")
    end
  end
end
