defmodule Yeesh.SessionTest do
  use ExUnit.Case, async: true

  alias Yeesh.Session

  setup do
    {:ok, pid} = Session.start_link(prompt: "test> ", history_max_size: 5)
    %{pid: pid}
  end

  describe "history" do
    test "push and retrieve history", %{pid: pid} do
      Session.push_history(pid, "echo hello")
      Session.push_history(pid, "help")

      history = Session.get_history(pid)
      assert [_, _] = history
      assert "help" in history
      assert "echo hello" in history
    end

    test "history respects max size", %{pid: pid} do
      for i <- 1..10, do: Session.push_history(pid, "cmd #{i}")
      # Need a small delay for casts to process
      Process.sleep(10)
      history = Session.get_history(pid)
      assert length(history) == 5
    end

    test "ignores blank lines", %{pid: pid} do
      Session.push_history(pid, "  ")
      Session.push_history(pid, "")
      Process.sleep(10)
      assert [] = Session.get_history(pid)
    end

    test "history navigation", %{pid: pid} do
      Session.push_history(pid, "first")
      Session.push_history(pid, "second")
      Process.sleep(10)

      assert {:ok, "second"} = Session.history_prev(pid)
      assert {:ok, "first"} = Session.history_prev(pid)
      assert {:ok, "second"} = Session.history_next(pid)
      assert :end = Session.history_next(pid)
    end
  end

  describe "prompt" do
    test "returns configured prompt", %{pid: pid} do
      assert "test> " = Session.get_prompt(pid)
    end

    test "returns iex prompt in elixir_repl mode", %{pid: pid} do
      Session.update(pid, fn s -> %{s | mode: :elixir_repl} end)
      assert "iex> " = Session.get_prompt(pid)
    end
  end

  describe "mode" do
    test "starts in normal mode", %{pid: pid} do
      assert :normal = Session.get_mode(pid)
    end
  end
end
