defmodule Yeesh.IOServerTest do
  use ExUnit.Case, async: true

  alias Yeesh.IOServer

  setup do
    {:ok, server} = IOServer.start_link()
    %{server: server}
  end

  describe "put_chars buffering" do
    test "buffers output from put_chars", %{server: server} do
      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          IO.write("hello")
          IO.write(" world")
        end)

      IOServer.monitor_task(server, task)
      {output, :done} = IOServer.start_and_wait(server)
      assert output == "hello world"
    end

    test "converts \\n to \\r\\n in output", %{server: server} do
      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          IO.puts("line one")
          IO.puts("line two")
        end)

      IOServer.monitor_task(server, task)
      {output, :done} = IOServer.start_and_wait(server)
      assert output == "line one\r\nline two\r\n"
    end

    test "preserves existing \\r\\n", %{server: server} do
      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          IO.write("already\r\ncorrect\r\n")
        end)

      IOServer.monitor_task(server, task)
      {output, :done} = IOServer.start_and_wait(server)
      assert output == "already\r\ncorrect\r\n"
    end
  end

  describe "get_line blocking" do
    test "blocks task on IO.gets and returns :waiting", %{server: server} do
      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          IO.puts("banner")
          IO.gets("prompt> ")
        end)

      IOServer.monitor_task(server, task)
      {output, :waiting, prompt} = IOServer.start_and_wait(server)
      assert output == "banner\r\n"
      assert prompt == "prompt> "

      # Clean up
      Process.exit(task, :kill)
    end

    test "task receives input after provide_input_and_wait", %{server: server} do
      test_pid = self()

      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          input = IO.gets("prompt> ")
          send(test_pid, {:got_input, String.trim(input)})
        end)

      IOServer.monitor_task(server, task)
      {_output, :waiting, _prompt} = IOServer.start_and_wait(server)
      {_output, :done} = IOServer.provide_input_and_wait(server, "hello")

      assert_receive {:got_input, "hello"}, 1000
    end
  end

  describe "interactive flow" do
    test "multi-turn conversation", %{server: server} do
      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          IO.puts("Welcome")

          input1 = IO.gets("1> ") |> String.trim()
          IO.puts("echo: #{input1}")

          input2 = IO.gets("2> ") |> String.trim()
          IO.puts("echo: #{input2}")

          IO.puts("Done")
        end)

      IOServer.monitor_task(server, task)

      # First: banner + first prompt
      {output1, :waiting, prompt1} = IOServer.start_and_wait(server)
      assert output1 == "Welcome\r\n"
      assert prompt1 == "1> "

      # Second: provide input, get echo + next prompt
      {output2, :waiting, prompt2} = IOServer.provide_input_and_wait(server, "first")
      assert output2 =~ "echo: first"
      assert prompt2 == "2> "

      # Third: provide input, task finishes
      {output3, :done} = IOServer.provide_input_and_wait(server, "second")
      assert output3 =~ "echo: second"
      assert output3 =~ "Done"
    end
  end

  describe "task exit detection" do
    test "reports :done when task exits normally", %{server: server} do
      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          IO.puts("done")
        end)

      IOServer.monitor_task(server, task)
      {output, :done} = IOServer.start_and_wait(server)
      assert output =~ "done"
    end

    test "reports :done when task crashes", %{server: server} do
      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          IO.puts("before crash")
          raise "boom"
        end)

      IOServer.monitor_task(server, task)
      {output, :done} = IOServer.start_and_wait(server)
      assert output =~ "before crash"
    end

    test "provide_input_and_wait returns :done for dead server", %{server: server} do
      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          IO.puts("hi")
          IO.gets("p> ")
        end)

      IOServer.monitor_task(server, task)
      {_, :waiting, _} = IOServer.start_and_wait(server)

      # Kill the task while we have a pending input
      Process.exit(task, :kill)
      Process.sleep(50)

      # Next provide_input should return :done
      {_output, :done} = IOServer.provide_input_and_wait(server, "anything")
    end
  end

  describe "getopts and setopts" do
    test "handles getopts request", %{server: server} do
      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          # :io.getopts/0 uses the group leader
          :io.getopts()
        end)

      IOServer.monitor_task(server, task)
      {_output, :done} = IOServer.start_and_wait(server)
    end
  end

  describe "normalize_newlines/1" do
    test "converts bare \\n to \\r\\n" do
      assert IOServer.normalize_newlines("a\nb\nc\n") == "a\r\nb\r\nc\r\n"
    end

    test "preserves existing \\r\\n" do
      assert IOServer.normalize_newlines("a\r\nb\r\n") == "a\r\nb\r\n"
    end

    test "handles mixed newlines" do
      assert IOServer.normalize_newlines("a\r\nb\nc\r\n") == "a\r\nb\r\nc\r\n"
    end

    test "handles empty string" do
      assert IOServer.normalize_newlines("") == ""
    end

    test "handles no newlines" do
      assert IOServer.normalize_newlines("no newlines") == "no newlines"
    end
  end

  describe "stop/1" do
    test "kills monitored task on stop", %{server: server} do
      task =
        spawn(fn ->
          Process.group_leader(self(), server)
          IO.gets("p> ")
        end)

      IOServer.monitor_task(server, task)
      Process.sleep(50)
      IOServer.stop(server)
      Process.sleep(50)
      refute Process.alive?(task)
    end
  end
end
