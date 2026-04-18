defmodule Yeesh.Completion do
  @moduledoc """
  Tab completion engine.

  Phase 1 (Milestone 1): command name prefix matching.
  Phase 2 (Milestone 2): argument-level completion via Command.completions/2.
  """

  alias Yeesh.Registry

  @doc """
  Returns completions for the given input and cursor position.

  Command names may be multi-word (e.g. `"mix run"`), so the prefix
  matched against the registry may itself contain spaces. Internal
  runs of whitespace in the input are collapsed to a single space
  before matching so that `"mix   ru"` and `"mix ru"` behave alike.

  If no registered command starts with the (normalized) prefix and
  the input contains a space, delegate to the command's
  `completions/2` callback (if implemented).
  """
  @spec complete(String.t(), non_neg_integer(), Yeesh.Session.t()) ::
          {[String.t()], String.t()}
  def complete(input, _cursor_pos, _session) do
    normalized = normalize_prefix(input)

    case Registry.completions_for(normalized) do
      [] ->
        if String.contains?(normalized, " ") do
          complete_args(normalized)
        else
          {[], normalized}
        end

      [single] ->
        {[], single <> " "}

      multiple ->
        {multiple, common_prefix(multiple)}
    end
  end

  defp normalize_prefix(input) do
    input
    |> String.trim_leading()
    |> String.replace(~r/[ \t]+/, " ")
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
