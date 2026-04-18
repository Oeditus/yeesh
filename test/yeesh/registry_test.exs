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

  describe "normalize_name/1" do
    test "trims leading and trailing whitespace" do
      assert "foo" = Registry.normalize_name("  foo  ")
    end

    test "collapses runs of internal whitespace" do
      assert "foo bar baz" = Registry.normalize_name("foo   bar\t\tbaz")
    end

    test "combines both" do
      assert "mix run" = Registry.normalize_name("\t  mix  \t run\t")
    end
  end

  describe "multi-word commands" do
    defmodule MultiWordCmd do
      @behaviour Yeesh.Command
      def name, do: "  deploy   now  "
      def description, do: "multi"
      def usage, do: "deploy now"
      def execute(_args, session), do: {:ok, "", session}
    end

    defmodule LongerCmd do
      @behaviour Yeesh.Command
      def name, do: "deploy now staging"
      def description, do: "longer"
      def usage, do: "deploy now staging"
      def execute(_args, session), do: {:ok, "", session}
    end

    setup do
      Registry.reset()
      :ok
    end

    test "name is normalized on registration and lookup works with irregular whitespace" do
      Registry.register(MultiWordCmd)
      assert "deploy now" in Registry.list()
      assert {:ok, MultiWordCmd} = Registry.lookup("deploy now")
      assert {:ok, MultiWordCmd} = Registry.lookup("  deploy  now  ")
    end

    test "match_command returns longest registered match" do
      Registry.register(MultiWordCmd)
      Registry.register(LongerCmd)

      assert {:ok, "deploy now", ["extra"]} =
               Registry.match_command(["deploy", "now", "extra"])

      assert {:ok, "deploy now staging", []} =
               Registry.match_command(["deploy", "now", "staging"])

      assert {:ok, "deploy now staging", ["v2"]} =
               Registry.match_command(["deploy", "now", "staging", "v2"])
    end

    test "match_command returns :error when no prefix matches" do
      assert :error = Registry.match_command(["nope"])
      assert :error = Registry.match_command([])
    end
  end
end
