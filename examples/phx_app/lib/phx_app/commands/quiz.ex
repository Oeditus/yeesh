defmodule PhxApp.Commands.Quiz do
  @moduledoc """
  Wraps `mix phx_app.quiz` as a named Yeesh terminal command.

  This demonstrates using `Yeesh.MixCommand` to expose a Mix task
  as a first-class terminal command without the `mix` prefix.

  Users can type `quiz` instead of `mix phx_app.quiz`.
  """

  use Yeesh.MixCommand,
    task: "phx_app.quiz",
    name: "quiz",
    description: "Play an interactive Elixir trivia quiz"
end
