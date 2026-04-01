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
  end
end
