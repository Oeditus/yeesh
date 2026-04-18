defmodule Yeesh.ExecutorTest do
  use ExUnit.Case, async: true

  alias Yeesh.Executor

  describe "tokenize/1" do
    test "simple command" do
      assert {:ok, ["echo", "hello"]} = Executor.tokenize("echo hello")
    end

    test "multiple arguments" do
      assert {:ok, ["cmd", "a", "b", "c"]} = Executor.tokenize("cmd a b c")
    end

    test "double-quoted strings" do
      assert {:ok, ["echo", "hello world"]} = Executor.tokenize(~s|echo "hello world"|)
    end

    test "single-quoted strings" do
      assert {:ok, ["echo", "hello world"]} = Executor.tokenize("echo 'hello world'")
    end

    test "escaped characters in quotes" do
      assert {:ok, ["echo", "it's fine"]} = Executor.tokenize(~s|echo "it\\'s fine"|)
    end

    test "multiple spaces between arguments" do
      assert {:ok, ["a", "b"]} = Executor.tokenize("a    b")
    end

    test "leading and trailing spaces" do
      assert {:ok, ["cmd"]} = Executor.tokenize("  cmd  ")
    end

    test "empty string" do
      assert {:ok, []} = Executor.tokenize("")
    end

    test "unterminated double quote" do
      assert {:error, "unterminated \" quote"} = Executor.tokenize(~s|echo "hello|)
    end

    test "unterminated single quote" do
      assert {:error, "unterminated ' quote"} = Executor.tokenize("echo 'hello")
    end

    test "mixed quoted and unquoted" do
      assert {:ok, ["env", "KEY=hello world"]} = Executor.tokenize(~s|env KEY="hello world"|)
    end

    test "tabs are treated as whitespace and collapsed" do
      assert {:ok, ["a", "b", "c"]} = Executor.tokenize("a\tb  \t c")
    end

    test "mixed leading/trailing whitespace is dropped" do
      assert {:ok, ["cmd", "arg"]} = Executor.tokenize("\t  cmd\targ \t ")
    end
  end

  describe "execute/2 with multi-word commands" do
    defmodule TwoWordCmd do
      @behaviour Yeesh.Command
      def name, do: "mix run"
      def description, do: "two-word"
      def usage, do: "mix run"
      def execute(args, session), do: {:ok, "TWO:#{Enum.join(args, ",")}", session}
    end

    defmodule ThreeWordCmd do
      @behaviour Yeesh.Command
      def name, do: "mix run once"
      def description, do: "three-word"
      def usage, do: "mix run once"
      def execute(args, session), do: {:ok, "THREE:#{Enum.join(args, ",")}", session}
    end

    defmodule SingleWordMix do
      @behaviour Yeesh.Command
      def name, do: "mix"
      def description, do: "one-word"
      def usage, do: "mix"
      def execute(args, session), do: {:ok, "ONE:#{Enum.join(args, ",")}", session}
    end

    defmodule PaddedNameCmd do
      @behaviour Yeesh.Command
      def name, do: "  foo   bar  "
      def description, do: "padded name"
      def usage, do: "foo bar"
      def execute(args, session), do: {:ok, "FB:#{Enum.join(args, ",")}", session}
    end

    setup do
      Yeesh.Registry.reset()
      Yeesh.Registry.register_all(Yeesh.Registry.resolve_builtins(:all))
      :ok
    end

    defp run(input) do
      {:ok, pid} = Yeesh.Session.start_link([])
      {out, _session} = Yeesh.Executor.execute(input, pid)
      out
    end

    test "dispatches to a registered two-word command" do
      Yeesh.Registry.register(TwoWordCmd)
      assert run("mix run") =~ "TWO:"
      assert run("mix run a b") =~ "TWO:a,b"
    end

    test "collapses runs of whitespace when matching" do
      Yeesh.Registry.register(TwoWordCmd)
      assert run("  mix    run   a   b  ") =~ "TWO:a,b"
    end

    test "prefers the longest registered match" do
      Yeesh.Registry.register(SingleWordMix)
      Yeesh.Registry.register(TwoWordCmd)
      Yeesh.Registry.register(ThreeWordCmd)

      assert run("mix") =~ "ONE:"
      assert run("mix other") =~ "ONE:other"
      assert run("mix run") =~ "TWO:"
      assert run("mix run a") =~ "TWO:a"
      assert run("mix run once") =~ "THREE:"
      assert run("mix run once extra") =~ "THREE:extra"
    end

    test "matches a multi-word command even when the single-word prefix is not registered" do
      Yeesh.Registry.register(TwoWordCmd)
      assert run("mix run something") =~ "TWO:something"
    end

    test "normalizes the registered command name" do
      Yeesh.Registry.register(PaddedNameCmd)
      assert "foo bar" in Yeesh.Registry.list()
      assert run("foo   bar baz") =~ "FB:baz"
    end
  end
end
