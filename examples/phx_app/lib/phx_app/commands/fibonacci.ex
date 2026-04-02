defmodule PhxApp.Commands.Fibonacci do
  @behaviour Yeesh.Command

  alias Yeesh.Output

  @impl true
  def name, do: "fib"

  @impl true
  def description, do: "Calculate Fibonacci numbers"

  @impl true
  def usage, do: "fib <n>  - compute the nth Fibonacci number (max 90)"

  @impl true
  def execute([], session) do
    {:error, "usage: fib <n>", session}
  end

  def execute([n_str | _], session) do
    case Integer.parse(n_str) do
      {n, ""} when n >= 0 and n <= 90 ->
        result = fib(n)

        output =
          Output.green("fib(#{n})") <>
            " = " <> Output.bold(Integer.to_string(result))

        {:ok, output, session}

      {n, ""} when n > 90 ->
        {:error, "too large (max 90)", session}

      _ ->
        {:error, "expected a non-negative integer", session}
    end
  end

  defp fib(0), do: 0
  defp fib(1), do: 1

  defp fib(n) do
    {result, _} =
      Enum.reduce(2..n, {1, 0}, fn _, {a, b} ->
        {a + b, a}
      end)

    result
  end
end
