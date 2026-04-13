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
end
