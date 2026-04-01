defmodule Yeesh.RegistryTest do
  use ExUnit.Case, async: false

  alias Yeesh.Registry

  describe "built-in commands" do
    test "registers all built-in commands on start" do
      commands = Registry.list()
      assert "help" in commands
      assert "clear" in commands
      assert "history" in commands
      assert "echo" in commands
      assert "env" in commands
      assert "elixir" in commands
    end

    test "list returns sorted command names" do
      [first | _] = Registry.list()
      assert is_binary(first)
    end
  end

  describe "lookup/1" do
    test "finds registered command" do
      assert {:ok, Yeesh.Builtin.Echo} = Registry.lookup("echo")
    end

    test "returns :error for unknown command" do
      assert :error = Registry.lookup("nonexistent_command_xyz")
    end
  end

  describe "completions_for/1" do
    test "returns matching command names" do
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
