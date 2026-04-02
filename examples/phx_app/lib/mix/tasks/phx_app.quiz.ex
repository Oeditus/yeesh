defmodule Mix.Tasks.PhxApp.Quiz do
  @shortdoc "Interactive Elixir trivia quiz"

  @moduledoc """
  An interactive Elixir trivia quiz.

  Demonstrates running interactive Mix tasks (with `IO.gets` loops)
  from the Yeesh browser terminal.

  ## Usage

      mix phx_app.quiz
  """

  use Mix.Task

  @questions [
    {"What operator is used for pattern matching in Elixir?", "="},
    {"What module provides the `|>` pipe operator?", "kernel"},
    {"What is the name of Elixir's build tool?", "mix"},
    {"What data structure does `%{}` create?", "map"},
    {"What keyword starts a module definition?", "defmodule"},
    {"What function sends a message to a process?", "send"},
    {"What is the file extension for Elixir scripts?", ".exs"},
    {"What OTP behaviour is used for stateful processes?", "genserver"}
  ]

  @impl true
  def run(_args) do
    IO.puts("")
    IO.puts("=== Elixir Trivia Quiz ===")
    IO.puts("")
    IO.puts("Answer each question (case-insensitive).")
    IO.puts("Type 'quit' to exit early.")
    IO.puts("")

    questions = Enum.shuffle(@questions) |> Enum.take(5)
    play(questions, 0, 0)
  end

  defp play([], correct, total) do
    IO.puts("")
    IO.puts("=== Results: #{correct}/#{total} correct ===")

    cond do
      correct == total -> IO.puts("Perfect score!")
      correct >= div(total, 2) -> IO.puts("Not bad!")
      true -> IO.puts("Better luck next time!")
    end

    IO.puts("")
  end

  defp play([{question, answer} | rest], correct, total) do
    IO.puts("Q#{total + 1}: #{question}")

    case IO.gets("answer> ") do
      :eof ->
        IO.puts("\nQuiz ended.")

      {:error, _} ->
        IO.puts("\nQuiz ended.")

      input ->
        input = input |> to_string() |> String.trim() |> String.downcase()

        cond do
          input == "quit" ->
            IO.puts("\nQuiz ended early.")
            play([], correct, total)

          input == String.downcase(answer) ->
            IO.puts("Correct!\n")
            play(rest, correct + 1, total + 1)

          true ->
            IO.puts("Wrong! The answer was: #{answer}\n")
            play(rest, correct, total + 1)
        end
    end
  end
end
