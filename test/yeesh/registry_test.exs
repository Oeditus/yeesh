defmodule Yeesh.RegistryTest do
  use ExUnit.Case, async: false

  alias Yeesh.Registry

  describe "built-in commands" do
    setup do
      Registry.reset()
      :ok
    end

    test "registers only help by default on start" do
      commands = Registry.list()
      assert ["help"] = commands
    end

    test "list returns sorted command names" do
      [first | _] = Registry.list()
      assert is_binary(first)
    end
  end

  describe "resolve_builtins/1" do
    test ":all returns all builtin modules" do
      modules = Registry.resolve_builtins(:all)
      assert Yeesh.Builtin.Help in modules
      assert Yeesh.Builtin.Clear in modules
      assert Yeesh.Builtin.History in modules
      assert Yeesh.Builtin.Echo in modules
      assert Yeesh.Builtin.Env in modules
      assert Yeesh.Builtin.ElixirEval in modules
    end

    test ":none returns an empty list" do
      assert [] = Registry.resolve_builtins(:none)
    end

    test ":help returns only the Help module" do
      assert [Yeesh.Builtin.Help] = Registry.resolve_builtins(:help)
    end

    test "a list of modules is returned as-is" do
      modules = [Yeesh.Builtin.Echo, Yeesh.Builtin.Env]
      assert ^modules = Registry.resolve_builtins(modules)
    end
  end

  describe "lookup/1" do
    test "finds registered command" do
      assert {:ok, Yeesh.Builtin.Help} = Registry.lookup("help")
    end

    test "returns :error for unknown command" do
      assert :error = Registry.lookup("nonexistent_command_xyz")
    end
  end

  describe "completions_for/1" do
    test "returns matching command names" do
      Registry.register_all(Registry.resolve_builtins(:all))
      matches = Registry.completions_for("e")
      assert "echo" in matches
      assert "elixir" in matches
      assert "env" in matches
    end

    test "returns empty for no matches" do
      assert [] = Registry.completions_for("zzz")
    end
  end

  describe "register/1" do
    defmodule TestCommand do
      @behaviour Yeesh.Command
      def name, do: "test_registry_cmd"
      def description, do: "test"
      def usage, do: "test"
      def execute(_args, session), do: {:ok, "ok", session}
    end

    test "registers a custom command" do
      Registry.register(TestCommand)
      assert {:ok, TestCommand} = Registry.lookup("test_registry_cmd")
    end
  end
end
