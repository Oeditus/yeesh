defmodule Yeesh.Builtin.History do
  @moduledoc false
  @behaviour Yeesh.Command

  alias Yeesh.Output

  @impl true
  def name, do: "history"

  @impl true
  def description, do: "Show command history"

  @impl true
  def usage, do: "history [count]"

  @impl true
  def execute([], session) do
    format_history(session.history, session)
  end

  def execute([count_str], session) do
    case Integer.parse(count_str) do
      {count, ""} when count > 0 ->
        format_history(Enum.take(session.history, count), session)

      _ ->
        {:error, "usage: history [count]", session}
    end
  end

  def execute(_args, session) do
    {:error, "usage: history [count]", session}
  end

  defp format_history(entries, session) do
    output =
      entries
      |> Enum.reverse()
      |> Enum.with_index(1)
      |> Enum.map_join("\r\n", fn {entry, idx} ->
        num = String.pad_leading(Integer.to_string(idx), 4)
        Output.dim(num <> "  ") <> entry
      end)

    {:ok, output, session}
  end
end
