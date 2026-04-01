defmodule Yeesh.Builtin.Env do
  @moduledoc false
  @behaviour Yeesh.Command

  alias Yeesh.Output

  @impl true
  def name, do: "env"

  @impl true
  def description, do: "Show or set environment variables"

  @impl true
  def usage,
    do:
      "env              - show all variables\nenv KEY          - show a variable\nenv KEY=VALUE    - set a variable"

  @impl true
  def completions(partial, session) do
    session.env
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, partial))
  end

  @impl true
  def execute([], session) do
    if map_size(session.env) == 0 do
      {:ok, Output.dim("(no environment variables set)"), session}
    else
      output =
        session.env
        |> Enum.sort()
        |> Enum.map_join("\r\n", fn {k, v} -> Output.cyan(k) <> "=" <> v end)

      {:ok, output, session}
    end
  end

  def execute([arg], session) do
    if String.contains?(arg, "=") do
      [key | rest] = String.split(arg, "=", parts: 2)
      value = Enum.join(rest, "=")
      new_session = %{session | env: Map.put(session.env, key, value)}
      {:ok, "", new_session}
    else
      case Map.fetch(session.env, arg) do
        {:ok, value} -> {:ok, value, session}
        :error -> {:error, "variable not found: #{arg}", session}
      end
    end
  end

  def execute([key, "=" | rest], session) do
    value = Enum.join(rest, " ")
    new_session = %{session | env: Map.put(session.env, key, value)}
    {:ok, "", new_session}
  end

  def execute(_args, session) do
    {:error, "usage: env [KEY[=VALUE]]", session}
  end
end
