defmodule Yeesh.Builtin.ElixirEval do
  @moduledoc false
  @behaviour Yeesh.Command

  alias Yeesh.{Output, Sandbox}

  @impl true
  def name, do: "elixir"

  @impl true
  def description, do: "Evaluate Elixir code in a sandboxed environment (Dune)"

  @impl true
  def usage,
    do:
      "elixir <expression>  - evaluate a one-shot expression\nelixir               - enter interactive Elixir REPL (type 'exit' to leave)"

  @impl true
  def execute([], session) do
    new_session = %{session | mode: :elixir_repl}

    output =
      Output.cyan("Entering sandboxed Elixir REPL (powered by Dune).") <>
        "\r\n" <>
        Output.dim("Type 'exit' to return to the shell.")

    {:ok, output, new_session}
  end

  def execute(args, session) do
    code = Enum.join(args, " ")

    case Sandbox.eval(session.dune_session, code) do
      {:ok, inspected, stdio, new_dune} ->
        output = build_output(inspected, stdio)
        {:ok, output, %{session | dune_session: new_dune}}

      {:error, message, new_dune} ->
        {:error, message, %{session | dune_session: new_dune}}
    end
  end

  defp build_output(inspected, stdio) do
    parts = []
    parts = if stdio != "", do: parts ++ [stdio], else: parts
    parts = parts ++ [Output.cyan(inspected)]
    Enum.join(parts, "")
  end
end
