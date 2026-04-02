defmodule Yeesh.MixRunnerTest do
  use ExUnit.Case, async: false

  alias Yeesh.{IOServer, MixRunner}

  describe "non-interactive tasks" do
    test "runs a simple echo task and returns output" do
      assert {:completed, output} = MixRunner.run("yeesh_test.echo", ["hello", "world"])
      assert output =~ "hello world"
    end

    test "runs a multi-output task" do
      assert {:completed, output} = MixRunner.run("yeesh_test.multi_output", ["3"])
      assert output =~ "line 1"
      assert output =~ "line 2"
      assert output =~ "line 3"
    end

    test "output has \\r\\n newlines" do
      {:completed, output} = MixRunner.run("yeesh_test.echo", ["test"])
      assert output =~ "\r\n"
      # Verify no bare \n (not preceded by \r) exists
      bare_newline = Regex.compile!("(?<!\\r)\\n")
      refute Regex.match?(bare_newline, output)
    end
  end

  describe "interactive tasks" do
    test "returns :interactive for tasks that call IO.gets" do
      assert {:interactive, io_server, task_pid, output, prompt} =
               MixRunner.run("yeesh_test.interactive")

      assert is_pid(io_server)
      assert is_pid(task_pid)
      assert output =~ "Welcome"
      assert prompt == "test> "

      # Clean up
      Process.exit(task_pid, :kill)
      if Process.alive?(io_server), do: IOServer.stop(io_server)
    end

    test "interactive task receives input and responds" do
      {:interactive, io_server, task_pid, _output, _prompt} =
        MixRunner.run("yeesh_test.interactive")

      {output, :waiting, prompt} = IOServer.provide_input_and_wait(io_server, "hello")
      assert output =~ "echo: hello"
      assert prompt == "test> "

      # Quit
      {output, :done} = IOServer.provide_input_and_wait(io_server, "quit")
      assert output =~ "Goodbye!"

      Process.sleep(50)
      refute Process.alive?(task_pid)
    end

    test "multi-turn interactive session" do
      {:interactive, io_server, task_pid, _output, _prompt} =
        MixRunner.run("yeesh_test.interactive")

      {out1, :waiting, _} = IOServer.provide_input_and_wait(io_server, "first")
      assert out1 =~ "echo: first"

      {out2, :waiting, _} = IOServer.provide_input_and_wait(io_server, "second")
      assert out2 =~ "echo: second"

      {out3, :done} = IOServer.provide_input_and_wait(io_server, "quit")
      assert out3 =~ "Goodbye!"

      Process.sleep(50)
      refute Process.alive?(task_pid)
    end
  end

  describe "error handling" do
    test "returns error for unknown task" do
      assert {:error, "unknown Mix task: nonexistent.task"} =
               MixRunner.run("nonexistent.task")
    end

    test "handles task crash gracefully" do
      assert {:completed, output} = MixRunner.run("yeesh_test.crash")
      assert output =~ "Error running mix yeesh_test.crash"
      assert output =~ "intentional crash"
    end
  end

  describe "cleanup/2" do
    test "stops the IOServer" do
      {:ok, io_server} = IOServer.start_link()
      assert Process.alive?(io_server)
      MixRunner.cleanup(io_server)
      Process.sleep(50)
      refute Process.alive?(io_server)
    end

    test "handles already-stopped IOServer" do
      {:ok, io_server} = IOServer.start_link()
      IOServer.stop(io_server)
      Process.sleep(50)
      assert :ok = MixRunner.cleanup(io_server)
    end
  end
end
