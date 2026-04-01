defmodule Yeesh.Sandbox do
  @moduledoc """
  Dune-powered sandboxed Elixir evaluation.

  Wraps `Dune.Session` for safe, stateful Elixir code evaluation.
  Variables persist across inputs within a session.

  ## Configuration

  Sandbox options can be passed via `:sandbox_opts`:

    - `:timeout` - evaluation timeout in ms (default: 5000)
    - `:max_reductions` - max reductions (default: 50_000)
    - `:max_heap_size` - max heap size in words (default: 1_000_000)
    - `:allowlist` - custom Dune allowlist module (default: Dune.Allowlist.Default)
  """

  @type dune_state :: term()

  @default_opts [
    timeout: 5_000,
    max_reductions: 50_000,
    max_heap_size: 1_000_000
  ]

  @doc "Creates a new Dune session."
  @spec new_session(keyword()) :: dune_state()
  def new_session(opts \\ []) do
    Dune.Session.new()
    |> then(fn session ->
      # Store opts alongside the session for later use
      {session, Keyword.merge(@default_opts, opts)}
    end)
  end

  @doc """
  Evaluates Elixir code in the sandbox.

  Returns `{:ok, inspected_result, stdio, updated_dune_state}`
  or `{:error, message, updated_dune_state}`.
  """
  @spec eval(dune_state(), String.t()) ::
          {:ok, String.t(), String.t(), dune_state()}
          | {:error, String.t(), dune_state()}
  def eval({session, opts}, code) do
    dune_opts = build_dune_opts(opts)

    case Dune.Session.eval_string(session, code, dune_opts) do
      %Dune.Session{last_result: %Dune.Success{inspected: inspected, stdio: stdio}} = new_session ->
        {:ok, inspected, stdio, {new_session, opts}}

      %Dune.Session{last_result: %Dune.Failure{message: message}} = new_session ->
        {:error, message, {new_session, opts}}
    end
  end

  defp build_dune_opts(opts) do
    dune_opts = []

    dune_opts =
      if timeout = opts[:timeout],
        do: Keyword.put(dune_opts, :timeout, timeout),
        else: dune_opts

    dune_opts =
      if allowlist = opts[:allowlist],
        do: Keyword.put(dune_opts, :allowlist, allowlist),
        else: dune_opts

    dune_opts =
      if max_reductions = opts[:max_reductions],
        do: Keyword.put(dune_opts, :max_reductions, max_reductions),
        else: dune_opts

    dune_opts =
      if max_heap_size = opts[:max_heap_size],
        do: Keyword.put(dune_opts, :max_heap_size, max_heap_size),
        else: dune_opts

    dune_opts
  end
end
