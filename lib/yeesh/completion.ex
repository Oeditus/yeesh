defmodule Yeesh.Completion do
  @moduledoc """
  Tab completion engine.

  Phase 1 (Milestone 1): command name prefix matching.
  Phase 2 (Milestone 2): argument-level completion via Command.completions/2.
  """

  alias Yeesh.Registry

  @doc """
  Returns completions for the given input and cursor position.

  If the input contains no spaces, completes command names.
  If the input contains spaces, delegates to the command's
  `completions/2` callback (if implemented).
  """
  @spec complete(String.t(), non_neg_integer(), Yeesh.Session.t()) ::
          {[String.t()], String.t()}
  def complete(input, _cursor_pos, _session) do
    trimmed = String.trim_leading(input)

    if String.contains?(trimmed, " ") do
      complete_args(trimmed)
    else
      complete_command(trimmed)
    end
  end

  defp complete_command(prefix) do
    matches = Registry.completions_for(prefix)

    case matches do
      [] -> {[], prefix}
      [single] -> {[], single <> " "}
      multiple -> {multiple, common_prefix(multiple)}
    end
  end

  defp complete_args(input) do
    # Phase 2 (Milestone 2): delegate to command's completions/2
    # For now, return empty
    {[], input}
  end

  @doc "Finds the longest common prefix among a list of strings."
  @spec common_prefix([String.t()]) :: String.t()
  def common_prefix([]), do: ""
  def common_prefix([single]), do: single

  def common_prefix([first | rest]) do
    Enum.reduce(rest, first, fn str, acc ->
      common_prefix_pair(acc, str)
    end)
  end

  defp common_prefix_pair(a, b) do
    a_chars = String.graphemes(a)
    b_chars = String.graphemes(b)

    a_chars
    |> Enum.zip(b_chars)
    |> Enum.take_while(fn {x, y} -> x == y end)
    |> Enum.map_join("", &elem(&1, 0))
  end
end
