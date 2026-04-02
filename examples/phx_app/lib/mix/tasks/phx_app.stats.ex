defmodule Mix.Tasks.PhxApp.Stats do
  @shortdoc "Show BEAM runtime statistics"

  @moduledoc """
  Displays BEAM runtime statistics.

  A non-interactive Mix task that demonstrates running `mix` commands
  from the Yeesh browser terminal.

  ## Usage

      mix phx_app.stats
  """

  use Mix.Task

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    memory = :erlang.memory()

    IO.puts("--- BEAM Runtime Stats ---")
    IO.puts("")
    IO.puts("  Elixir:       #{System.version()}")
    IO.puts("  OTP:          #{:erlang.system_info(:otp_release)}")
    IO.puts("  Schedulers:   #{:erlang.system_info(:schedulers_online)}")
    IO.puts("  Processes:    #{:erlang.system_info(:process_count)}")
    IO.puts("  Atoms:        #{:erlang.system_info(:atom_count)}")
    IO.puts("  Memory total: #{format_bytes(memory[:total])}")
    IO.puts("  Memory procs: #{format_bytes(memory[:processes])}")
    IO.puts("  Memory ETS:   #{format_bytes(memory[:ets])}")
    IO.puts("  Uptime:       #{format_uptime(uptime_ms)}")
    IO.puts("")
    IO.puts("  Node: #{node()}")
  end

  defp format_bytes(bytes) when bytes >= 1_048_576,
    do: "#{Float.round(bytes / 1_048_576, 1)} MB"

  defp format_bytes(bytes) when bytes >= 1024,
    do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes), do: "#{bytes} B"

  defp format_uptime(ms) do
    seconds = div(ms, 1000)
    "#{div(seconds, 3600)}h #{div(rem(seconds, 3600), 60)}m #{rem(seconds, 60)}s"
  end
end
