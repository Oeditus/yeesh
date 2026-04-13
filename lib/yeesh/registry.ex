defmodule Yeesh.Registry do
  @moduledoc """
  ETS-backed command registry.

  Stores command modules keyed by their name. Only the `help` built-in
  is registered on application start. Additional built-ins are registered
  when the terminal component mounts according to the `:builtins` option
  (defaults to `:help`). Consumer commands are also registered on mount.

  See `resolve_builtins/1` for the accepted values of `:builtins`.
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

  @type builtins_opt :: :all | :none | :help | [module()]

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

  @doc "Clears the registry and re-registers only the default builtins (`:help`)."
  @spec reset :: :ok
  def reset do
    :ets.delete_all_objects(@table)
    register_all(resolve_builtins(:help))
  end

  @doc "Returns the list of built-in command modules."
  @spec builtin_commands :: [module()]
  def builtin_commands, do: @builtin_commands ++ mix_commands()

  @doc """
  Resolves a builtins option into a list of command modules.

  Accepted values:

    - `:all`  -- all built-in commands
    - `:none` -- no built-in commands
    - `:help` -- only the `help` command (default)
    - a list of command modules -- those exact modules
  """
  @spec resolve_builtins(builtins_opt()) :: [module()]
  def resolve_builtins(:all), do: @builtin_commands ++ mix_commands()
  def resolve_builtins(:none), do: []
  def resolve_builtins(:help), do: [Yeesh.Builtin.Help]
  def resolve_builtins(modules) when is_list(modules), do: modules

  # Server callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    register_all(resolve_builtins(:help))
    {:ok, table}
  end

  @doc false
  @spec mix_commands :: [module()]
  def mix_commands do
    if Application.get_env(:yeesh, :enable_mix_command, false) &&
         Code.ensure_loaded?(Yeesh.Builtin.MixTask) do
      [Yeesh.Builtin.MixTask]
    else
      []
    end
  end
end
