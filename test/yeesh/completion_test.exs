defmodule Yeesh.CompletionTest do
  use ExUnit.Case, async: false

  alias Yeesh.Completion

  describe "common_prefix/1" do
    test "single string" do
      assert "hello" = Completion.common_prefix(["hello"])
    end

    test "shared prefix" do
      assert "he" = Completion.common_prefix(["hello", "help", "heap"])
    end

    test "no shared prefix" do
      assert "" = Completion.common_prefix(["abc", "xyz"])
    end

    test "empty list" do
      assert "" = Completion.common_prefix([])
    end

    test "identical strings" do
      assert "same" = Completion.common_prefix(["same", "same"])
    end
  end

  describe "complete/3" do
    setup do
      Yeesh.Registry.register_all(Yeesh.Registry.resolve_builtins(:all))
      :ok
    end

    test "completes command names from registry" do
      session = %Yeesh.Session{}
      {matches, _replacement} = Completion.complete("e", 1, session)
      assert "echo" in matches
      assert "env" in matches
      assert "elixir" in matches
    end

    test "single match completes with space" do
      session = %Yeesh.Session{}
      {[], replacement} = Completion.complete("clea", 4, session)
      assert replacement == "clear "
    end

    test "no matches returns original" do
      session = %Yeesh.Session{}
      {[], replacement} = Completion.complete("zzz", 3, session)
      assert replacement == "zzz"
    end
  end

  describe "multi-word completion" do
    defmodule McRun do
      @behaviour Yeesh.Command
      def name, do: "mix run"
      def description, do: "two"
      def usage, do: "mix run"
      def execute(_args, session), do: {:ok, "", session}
    end

    defmodule McRunOnce do
      @behaviour Yeesh.Command
      def name, do: "mix run once"
      def description, do: "three"
      def usage, do: "mix run once"
      def execute(_args, session), do: {:ok, "", session}
    end

    setup do
      Yeesh.Registry.reset()
      Yeesh.Registry.register(McRun)
      Yeesh.Registry.register(McRunOnce)
      :ok
    end

    test "completes a multi-word command name after the first word" do
      session = %Yeesh.Session{}
      {matches, replacement} = Completion.complete("mix r", 5, session)
      assert "mix run" in matches
      assert "mix run once" in matches
      assert replacement == "mix run"
    end

    test "single multi-word match appends a space" do
      session = %Yeesh.Session{}
      {[], replacement} = Completion.complete("mix run o", 9, session)
      assert replacement == "mix run once "
    end

    test "collapses whitespace in the prefix before matching" do
      session = %Yeesh.Session{}
      {[], replacement} = Completion.complete("mix   run   o", 13, session)
      assert replacement == "mix run once "
    end
  end
end
