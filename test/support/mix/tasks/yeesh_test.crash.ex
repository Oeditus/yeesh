defmodule Mix.Tasks.YeeshTest.Crash do
  @shortdoc "Test task: crashes intentionally"
  @moduledoc "Mix task that raises for testing error handling."
  use Mix.Task

  @impl true
  def run(_args) do
    raise "intentional crash for testing"
  end
end
