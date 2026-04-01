defmodule Yeesh.Registry do
  @moduledoc """
  ETS-backed command registry.

  Stores command modules keyed by their name. Built-in commands are
  registered automatically on application start. Consumer commands
  are registered when the terminal component mounts.
  """

  use GenServer

  @table __MODULE__

  @builtin_commands [
    Yeesh.Builtin.Help,
    Yeesh.Builtin.Clear,
    Yeesh.Builtin.History,
    Yeesh.Builtin.Echo,
    Yeesh.Builtin.Env,
    Yeesh.Builtin.ElixirEval
  ]

  # Client API

  @doc "Starts the registry."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Registers a command module."
  @spec register(module()) :: :ok
  def register(command_module) do
    name = command_module.name()
    :ets.insert(@table, {name, command_module})
    :ok
  end

  @doc "Registers multiple command modules."
  @spec register_all([module()]) :: :ok
  def register_all(modules) do
    Enum.each(modules, &register/1)
  end

  @doc "Looks up a command module by name."
  @spec lookup(String.t()) :: {:ok, module()} | :error
  def lookup(name) do
    case :ets.lookup(@table, name) do
      [{^name, module}] -> {:ok, module}
      [] -> :error
    end
  end

  @doc "Returns all registered command names."
  @spec list :: [String.t()]
  def list do
    :ets.tab2list(@table)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  @doc "Returns all registered {name, module} pairs."
  @spec list_all :: [{String.t(), module()}]
  def list_all do
    :ets.tab2list(@table)
    |> Enum.sort_by(&elem(&1, 0))
  end

  @doc "Returns command names matching the given prefix."
  @spec completions_for(String.t()) :: [String.t()]
  def completions_for(prefix) do
    list()
    |> Enum.filter(&String.starts_with?(&1, prefix))
  end

  @doc "Returns the list of built-in command modules."
  @spec builtin_commands :: [module()]
  def builtin_commands, do: @builtin_commands

  # Server callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    register_all(@builtin_commands)
    {:ok, table}
  end
end
