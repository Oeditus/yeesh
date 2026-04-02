defmodule Yeesh.MixCommandTest do
  use ExUnit.Case, async: false

  alias Yeesh.Test.EchoCommand

  describe "generated command module" do
    test "implements name/0" do
      assert "test_echo" = EchoCommand.name()
    end

    test "implements description/0" do
      assert "Test echo via MixCommand macro" = EchoCommand.description()
    end

    test "implements usage/0" do
      assert "test_echo [args...]" = EchoCommand.usage()
    end

    test "execute/2 runs the wrapped task with default_args" do
      session = build_session()
      assert {:ok, output, _session} = EchoCommand.execute([], session)
      assert output =~ "default_arg"
    end

    test "execute/2 appends user args after default_args" do
      session = build_session()
      assert {:ok, output, _session} = EchoCommand.execute(["extra"], session)
      assert output =~ "default_arg extra"
    end

    test "execute/2 returns error for broken task" do
      # Define a command wrapping a nonexistent task
      defmodule BrokenCommand do
        use Yeesh.MixCommand,
          task: "nonexistent.task",
          name: "broken",
          description: "Broken"
      end

      session = build_session()
      assert {:error, reason, _session} = BrokenCommand.execute([], session)
      assert reason =~ "unknown Mix task"
    end
  end

  defp build_session do
    %Yeesh.Session{
      history: [],
      history_max_size: 100,
      history_index: -1,
      env: %{},
      cwd: "/",
      prompt: "$ ",
      mode: :normal,
      dune_session: nil,
      context: %{},
      started_at: DateTime.utc_now()
    }
  end
end
