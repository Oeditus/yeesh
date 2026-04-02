defmodule Mix.Tasks.YeeshTest.Interactive do
  @shortdoc "Test task: interactive REPL"
  @moduledoc "Interactive Mix task for testing. Reads lines and echoes them back."
  use Mix.Task

  @impl true
  def run(_args) do
    IO.puts("Welcome to interactive test")
    loop()
  end

  defp loop do
    case IO.gets("test> ") do
      :eof ->
        IO.puts("Goodbye!")

      {:error, _} ->
        IO.puts("Goodbye!")

      input ->
        input = String.trim(input)

        case input do
          "quit" ->
            IO.puts("Goodbye!")

          _ ->
            IO.puts("echo: #{input}")
            loop()
        end
    end
  end
end
