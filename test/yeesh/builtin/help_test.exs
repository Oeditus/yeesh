defmodule Yeesh.Builtin.HelpTest do
  use ExUnit.Case, async: false

  alias Yeesh.{Builtin.Help, Registry, Session}

  setup do
    Registry.reset()
    :ok
  end

  describe "execute/2 grouping" do
    test "groups builtin commands under Built-in" do
      Registry.register_all(Registry.resolve_builtins(:all))
      {:ok, output, _session} = Help.execute([], %Session{})
      assert output =~ "Built-in:"
      assert output =~ "help"
      assert output =~ "clear"
    end

    test "groups plain consumer commands under Generic" do
      defmodule PlainCmd do
        @behaviour Yeesh.Command
        def name, do: "deploy"
        def description, do: "Deploy the app"
        def usage, do: "deploy"
        def execute(_args, session), do: {:ok, "", session}
      end

      Registry.register(PlainCmd)
      {:ok, output, _session} = Help.execute([], %Session{})
      assert output =~ "Generic:"
      assert output =~ "deploy"
    end

    test "groups dotted commands by prefix" do
      defmodule DottedCmd do
        @behaviour Yeesh.Command
        def name, do: "sys.info"
        def description, do: "System info"
        def usage, do: "sys.info"
        def execute(_args, session), do: {:ok, "", session}
      end

      Registry.register(DottedCmd)
      {:ok, output, _session} = Help.execute([], %Session{})
      assert output =~ "Sys:"
    end

    test "groups dashed commands by prefix" do
      defmodule DashedCmd do
        @behaviour Yeesh.Command
        def name, do: "db-migrate"
        def description, do: "Run migrations"
        def usage, do: "db-migrate"
        def execute(_args, session), do: {:ok, "", session}
      end

      Registry.register(DashedCmd)
      {:ok, output, _session} = Help.execute([], %Session{})
      assert output =~ "Db:"
    end

    test "groups underscored commands by prefix" do
      defmodule UnderscoredCmd do
        @behaviour Yeesh.Command
        def name, do: "cache_clear"
        def description, do: "Clear cache"
        def usage, do: "cache_clear"
        def execute(_args, session), do: {:ok, "", session}
      end

      Registry.register(UnderscoredCmd)
      {:ok, output, _session} = Help.execute([], %Session{})
      assert output =~ "Cache:"
    end

    test "Built-in group appears before Generic and custom groups" do
      defmodule SortTestCmd do
        @behaviour Yeesh.Command
        def name, do: "zulu.cmd"
        def description, do: "Test"
        def usage, do: "zulu.cmd"
        def execute(_args, session), do: {:ok, "", session}
      end

      Registry.register_all(Registry.resolve_builtins(:all))
      Registry.register(SortTestCmd)
      {:ok, output, _session} = Help.execute([], %Session{})

      builtin_pos = :binary.match(output, "Built-in:") |> elem(0)
      zulu_pos = :binary.match(output, "Zulu:") |> elem(0)
      assert builtin_pos < zulu_pos
    end
  end
end
