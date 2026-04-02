defmodule Yeesh.Session do
  @moduledoc """
  Per-terminal session state, managed as a GenServer.

  Each terminal instance gets its own session holding command history,
  environment variables, working directory, prompt config, and the
  Dune sandbox state for Elixir evaluation.
  """

  use GenServer

  alias Yeesh.Sandbox

  @type t :: %__MODULE__{
          history: [String.t()],
          history_max_size: pos_integer(),
          history_index: integer(),
          env: %{String.t() => String.t()},
          cwd: String.t(),
          prompt: String.t(),
          mode: :normal | :elixir_repl | :mix_task,
          dune_session: Sandbox.dune_state(),
          context: map(),
          started_at: DateTime.t()
        }

  defstruct history: [],
            history_max_size: 1000,
            history_index: -1,
            env: %{},
            cwd: "/",
            prompt: "$ ",
            mode: :normal,
            dune_session: nil,
            context: %{},
            started_at: nil

  # Client API

  @doc "Starts a new session under the DynamicSupervisor."
  @spec start(keyword()) :: {:ok, pid()} | {:error, term()}
  def start(opts \\ []) do
    DynamicSupervisor.start_child(Yeesh.SessionSupervisor, {__MODULE__, opts})
  end

  @doc "Starts a session linked to the caller."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Returns the current session state."
  @spec get_state(pid()) :: t()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc "Updates the session state with the given function."
  @spec update(pid(), (t() -> t())) :: t()
  def update(pid, fun) when is_function(fun, 1) do
    GenServer.call(pid, {:update, fun})
  end

  @doc "Adds a command to the history."
  @spec push_history(pid(), String.t()) :: :ok
  def push_history(pid, command) do
    GenServer.cast(pid, {:push_history, command})
  end

  @doc "Gets the previous history entry (up arrow)."
  @spec history_prev(pid()) :: {:ok, String.t()} | :empty
  def history_prev(pid) do
    GenServer.call(pid, :history_prev)
  end

  @doc "Gets the next history entry (down arrow)."
  @spec history_next(pid()) :: {:ok, String.t()} | :end
  def history_next(pid) do
    GenServer.call(pid, :history_next)
  end

  @doc "Resets the history navigation index."
  @spec reset_history_index(pid()) :: :ok
  def reset_history_index(pid) do
    GenServer.cast(pid, :reset_history_index)
  end

  @doc "Returns the full history list."
  @spec get_history(pid()) :: [String.t()]
  def get_history(pid) do
    GenServer.call(pid, :get_history)
  end

  @doc "Gets the current prompt string."
  @spec get_prompt(pid()) :: String.t()
  def get_prompt(pid) do
    GenServer.call(pid, :get_prompt)
  end

  @doc "Gets the current mode."
  @spec get_mode(pid()) :: :normal | :elixir_repl | :mix_task
  def get_mode(pid) do
    GenServer.call(pid, :get_mode)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    config = Yeesh.config(opts)

    state = %__MODULE__{
      history_max_size: Keyword.get(config, :history_max_size, 1000),
      prompt: Keyword.get(config, :prompt, "$ "),
      context: Keyword.get(opts, :context, %{}),
      dune_session: Sandbox.new_session(Keyword.get(config, :sandbox_opts, [])),
      started_at: DateTime.utc_now()
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:update, fun}, _from, state) do
    new_state = fun.(state)
    {:reply, new_state, new_state}
  end

  def handle_call(:history_prev, _from, %{history: []} = state) do
    {:reply, :empty, state}
  end

  def handle_call(:history_prev, _from, state) do
    new_index = min(state.history_index + 1, length(state.history) - 1)

    case Enum.at(state.history, new_index) do
      nil -> {:reply, :empty, state}
      entry -> {:reply, {:ok, entry}, %{state | history_index: new_index}}
    end
  end

  def handle_call(:history_next, _from, state) do
    new_index = state.history_index - 1

    if new_index < 0 do
      {:reply, :end, %{state | history_index: -1}}
    else
      case Enum.at(state.history, new_index) do
        nil -> {:reply, :end, %{state | history_index: -1}}
        entry -> {:reply, {:ok, entry}, %{state | history_index: new_index}}
      end
    end
  end

  def handle_call(:get_history, _from, state) do
    {:reply, state.history, state}
  end

  def handle_call(:get_prompt, _from, state) do
    prompt =
      case state.mode do
        :normal -> state.prompt
        :elixir_repl -> "iex> "
        :mix_task -> Map.get(state.context, :mix_prompt, "mix> ")
      end

    {:reply, prompt, state}
  end

  def handle_call(:get_mode, _from, state) do
    {:reply, state.mode, state}
  end

  @impl true
  def handle_cast({:push_history, command}, state) do
    trimmed = String.trim(command)

    if trimmed == "" do
      {:noreply, state}
    else
      history =
        [trimmed | state.history]
        |> Enum.take(state.history_max_size)

      {:noreply, %{state | history: history, history_index: -1}}
    end
  end

  def handle_cast(:reset_history_index, state) do
    {:noreply, %{state | history_index: -1}}
  end
end
