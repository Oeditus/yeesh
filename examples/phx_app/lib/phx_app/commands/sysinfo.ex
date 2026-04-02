defmodule PhxApp.Commands.Sysinfo do
  @behaviour Yeesh.Command

  alias Yeesh.Output

  @impl true
  def name, do: "sysinfo"

  @impl true
  def description, do: "Display BEAM/system information"

  @impl true
  def usage, do: "sysinfo"

  @impl true
  def execute(_args, session) do
    info = [
      {Output.cyan("Elixir"), System.version()},
      {Output.cyan("OTP"), :erlang.system_info(:otp_release) |> List.to_string()},
      {Output.cyan("Schedulers"), :erlang.system_info(:schedulers_online) |> Integer.to_string()},
      {Output.cyan("Processes"), :erlang.system_info(:process_count) |> Integer.to_string()},
      {Output.cyan("Memory (total)"), format_bytes(:erlang.memory(:total))},
      {Output.cyan("Memory (procs)"), format_bytes(:erlang.memory(:processes))},
      {Output.cyan("Uptime"), format_uptime()},
      {Output.cyan("Node"), Atom.to_string(node())}
    ]

    output =
      info
      |> Enum.map(fn {label, value} ->
        String.pad_trailing(label <> Output.reset(), 30) <> value
      end)
      |> Enum.join("\r\n")

    {:ok, Output.bold("System Information") <> "\r\n\r\n" <> output, session}
  end

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_073_741_824 ->
        "#{Float.round(bytes / 1_073_741_824, 1)} GB"

      bytes >= 1_048_576 ->
        "#{Float.round(bytes / 1_048_576, 1)} MB"

      bytes >= 1024 ->
        "#{Float.round(bytes / 1024, 1)} KB"

      true ->
        "#{bytes} B"
    end
  end

  defp format_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    seconds = div(uptime_ms, 1000)

    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    "#{hours}h #{minutes}m #{secs}s"
  end
end
