defmodule Yeesh.MixTaskIntegrationTest do
  use ExUnit.Case, async: false

  alias Yeesh.{Executor, Session}

  setup do
    Yeesh.Registry.register_all(Yeesh.Registry.resolve_builtins(:all))
    {:ok, pid} = Session.start_link(prompt: "$ ")
    %{session_pid: pid}
  end

  describe "non-interactive mix task via Executor" do
    test "mix command runs non-interactive task", %{session_pid: pid} do
      {output, session} = Executor.execute("mix yeesh_test.echo hello world", pid)
      assert output =~ "hello world"
      assert session.mode == :normal
    end

    test "mix command with multi-line output", %{session_pid: pid} do
      {output, session} = Executor.execute("mix yeesh_test.multi_output 2", pid)
      assert output =~ "line 1"
      assert output =~ "line 2"
      assert session.mode == :normal
    end

    test "mix command without args lists tasks", %{session_pid: pid} do
      {output, session} = Executor.execute("mix", pid)
      assert output =~ "Available Mix tasks:"
      assert session.mode == :normal
    end

    test "mix command with unknown task returns error", %{session_pid: pid} do
      {output, session} = Executor.execute("mix nonexistent.task", pid)
      assert output =~ "unknown Mix task"
      assert session.mode == :normal
    end
  end

  describe "interactive mix task via Executor" do
    test "enters :mix_task mode for interactive tasks", %{session_pid: pid} do
      {output, session} = Executor.execute("mix yeesh_test.interactive", pid)
      assert output =~ "Welcome"
      assert session.mode == :mix_task
      assert is_pid(session.context[:mix_io_server])
      assert is_pid(session.context[:mix_task_pid])
      assert session.context[:mix_prompt] == "test> "

      # Clean up
      cleanup_mix_task(session)
    end

    test "forwards input to interactive task", %{session_pid: pid} do
      {_output, session} = Executor.execute("mix yeesh_test.interactive", pid)
      assert session.mode == :mix_task

      # Send input in :mix_task mode
      {output, session} = Executor.execute("hello", pid)
      assert output =~ "echo: hello"
      assert session.mode == :mix_task

      # Clean up
      cleanup_mix_task(session)
    end

    test "returns to :normal mode when task exits", %{session_pid: pid} do
      {_output, _session} = Executor.execute("mix yeesh_test.interactive", pid)

      # Send "quit" which makes the test task exit
      {output, session} = Executor.execute("quit", pid)
      assert output =~ "Goodbye!"
      assert session.mode == :normal
      refute Map.has_key?(session.context, :mix_io_server)
    end

    test "exit command forces task termination", %{session_pid: pid} do
      {_output, session} = Executor.execute("mix yeesh_test.interactive", pid)
      assert session.mode == :mix_task

      # The "exit" keyword in :mix_task mode kills the task
      {_output, session} = Executor.execute("exit", pid)
      assert session.mode == :normal
    end

    test "multi-turn interactive session through Executor", %{session_pid: pid} do
      {out1, _} = Executor.execute("mix yeesh_test.interactive", pid)
      assert out1 =~ "Welcome"

      {out2, _} = Executor.execute("first message", pid)
      assert out2 =~ "echo: first message"

      {out3, _} = Executor.execute("second message", pid)
      assert out3 =~ "echo: second message"

      {out4, session} = Executor.execute("quit", pid)
      assert out4 =~ "Goodbye!"
      assert session.mode == :normal
    end

    test "prompt updates correctly during interactive session", %{session_pid: pid} do
      {_output, _session} = Executor.execute("mix yeesh_test.interactive", pid)

      prompt = Session.get_prompt(pid)
      assert prompt == "test> "

      # After exiting, prompt reverts
      Executor.execute("quit", pid)
      prompt = Session.get_prompt(pid)
      assert prompt == "$ "
    end
  end

  describe "mix task with crashing task" do
    test "handles task crash and returns output", %{session_pid: pid} do
      {output, session} = Executor.execute("mix yeesh_test.crash", pid)
      assert output =~ "intentional crash"
      assert session.mode == :normal
    end
  end

  defp cleanup_mix_task(session) do
    if pid = session.context[:mix_task_pid] do
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end

    if server = session.context[:mix_io_server] do
      if Process.alive?(server), do: Yeesh.IOServer.stop(server)
    end
  end
end
