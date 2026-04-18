defmodule Yeesh.Executor do
  @moduledoc """
  Parses and executes commands.

  Tokenizes input into command name + arguments (respecting quoting),
  looks up the command in the registry, and executes it.

  Execution is synchronous in the current release.
  Async streaming execution is planned for Milestone 3.

  OS command passthrough is planned for Milestone 2.
  """

  alias Yeesh.{IOServer, Output, Registry, Sandbox, Session}

  @doc """
  Executes a command line in the context of the given session.

  Returns `{output, updated_session_state}`.
  """
  @spec execute(String.t(), pid()) :: {String.t(), Yeesh.Session.t()}
  def execute(input, session_pid) do
    input = String.trim(input)
    session = Session.get_state(session_pid)

    if input == "" do
      {"", session}
    else
      result =
        case session.mode do
          :elixir_repl -> execute_elixir_repl(input, session, session_pid)
          :mix_task -> execute_mix_task(input, session, session_pid)
          :normal -> execute_normal(input, session, session_pid)
        end

      # Push history after execution so the cast is processed after any
      # synchronous Session.update/2 calls made during dispatch, avoiding
      # the history entry being overwritten by a full-state replacement.
      Session.push_history(session_pid, input)

      result
    end
  end

  defp execute_normal(input, session, session_pid) do
    case tokenize(input) do
      {:ok, []} ->
        {"", session}

      {:ok, [first | rest] = tokens} ->
        {command_name, args} =
          case Registry.match_command(tokens) do
            {:ok, name, remaining} -> {name, remaining}
            :error -> {first, rest}
          end

        dispatch(command_name, args, session, session_pid)

      {:error, reason} ->
        {Output.error(reason), session}
    end
  end

  defp execute_elixir_repl("exit", _session, session_pid) do
    new_session = Session.update(session_pid, fn s -> %{s | mode: :normal} end)
    {"", new_session}
  end

  defp execute_elixir_repl(input, session, session_pid) do
    case Sandbox.eval(session.dune_session, input) do
      {:ok, inspected, stdio, new_dune} ->
        output = build_elixir_output(inspected, stdio)
        new_session = Session.update(session_pid, fn s -> %{s | dune_session: new_dune} end)
        {output, new_session}

      {:error, message, new_dune} ->
        new_session = Session.update(session_pid, fn s -> %{s | dune_session: new_dune} end)
        {Output.red(message), new_session}
    end
  end

  defp build_elixir_output(inspected, stdio) do
    parts = []
    parts = if stdio != "", do: parts ++ [stdio], else: parts
    parts = parts ++ [Output.cyan(inspected)]
    Enum.join(parts, "")
  end

  # -- Mix task mode -----------------------------------------------------------

  defp execute_mix_task("exit", session, session_pid) do
    cleanup_mix_task(session, session_pid)
  end

  defp execute_mix_task(input, session, session_pid) do
    io_server = session.context[:mix_io_server]

    if io_server && Process.alive?(io_server) do
      forward_to_mix_task(io_server, input, session, session_pid)
    else
      cleanup_mix_task(session, session_pid)
    end
  rescue
    _ -> cleanup_mix_task(session, session_pid)
  end

  defp forward_to_mix_task(io_server, input, session, session_pid) do
    case IOServer.provide_input_and_wait(io_server, input) do
      {output, :waiting, prompt} ->
        new_session =
          Session.update(session_pid, fn s ->
            %{s | context: Map.put(s.context, :mix_prompt, prompt)}
          end)

        {output, new_session}

      {output, :done} ->
        {done_output, new_session} = cleanup_mix_task(session, session_pid)
        {output <> done_output, new_session}
    end
  end

  defp cleanup_mix_task(session, session_pid) do
    io_server = session.context[:mix_io_server]
    task_pid = session.context[:mix_task_pid]
    original_shell = session.context[:mix_original_shell]

    # Kill the task if still alive
    if task_pid && Process.alive?(task_pid) do
      Process.exit(task_pid, :kill)
    end

    # Clean up IOServer
    if io_server && Process.alive?(io_server) do
      IOServer.stop(io_server)
    end

    # Restore Mix.shell if Mix is available
    if Code.ensure_loaded?(Mix) && original_shell do
      Mix.shell(original_shell)
    end

    new_session =
      Session.update(session_pid, fn s ->
        %{
          s
          | mode: :normal,
            context:
              s.context
              |> Map.delete(:mix_io_server)
              |> Map.delete(:mix_task_pid)
              |> Map.delete(:mix_prompt)
              |> Map.delete(:mix_original_shell)
        }
      end)

    {"", new_session}
  end

  defp dispatch(command_name, args, session, session_pid) do
    case Registry.lookup(command_name) do
      {:ok, module} ->
        try do
          case module.execute(args, session) do
            {:ok, output, new_session} ->
              Session.update(session_pid, fn _s -> new_session end)
              {output, new_session}

            {:error, reason, new_session} ->
              Session.update(session_pid, fn _s -> new_session end)
              {Output.error(reason), new_session}
          end
        rescue
          e ->
            {Output.error("command crashed: #{Exception.message(e)}"), session}
        end

      :error ->
        {Output.error("command not found: #{command_name}"), session}
    end
  end

  @doc """
  Tokenizes a command line into a list of strings, respecting
  single and double quoting.

  ## Examples

      iex> Yeesh.Executor.tokenize(~s|echo "hello world"|)
      {:ok, ["echo", "hello world"]}

      iex> Yeesh.Executor.tokenize(~s|echo 'it\\'s fine'|)
      {:ok, ["echo", "it's fine"]}
  """
  @spec tokenize(String.t()) :: {:ok, [String.t()]} | {:error, String.t()}
  def tokenize(input) do
    do_tokenize(String.trim(input), [], "", nil)
  end

  defp do_tokenize("", tokens, "", _quote) do
    {:ok, Enum.reverse(tokens)}
  end

  defp do_tokenize("", tokens, current, nil) do
    {:ok, Enum.reverse([current | tokens])}
  end

  defp do_tokenize("", _tokens, _current, quote_char) do
    {:error, "unterminated #{quote_char} quote"}
  end

  # Escape character inside quotes
  defp do_tokenize(<<"\\", c, rest::binary>>, tokens, current, quote_char)
       when quote_char != nil do
    do_tokenize(rest, tokens, current <> <<c>>, quote_char)
  end

  # Opening/closing quotes
  defp do_tokenize(<<q, rest::binary>>, tokens, current, nil)
       when q in [?", ?'] do
    do_tokenize(rest, tokens, current, <<q>>)
  end

  defp do_tokenize(<<q, rest::binary>>, tokens, current, <<q>>) do
    do_tokenize(rest, tokens, current, nil)
  end

  # Whitespace outside quotes = token separator. Runs of whitespace
  # collapse into a single separator; leading/trailing whitespace is
  # dropped entirely.
  defp do_tokenize(<<c, rest::binary>>, tokens, "", nil) when c in [?\s, ?\t] do
    do_tokenize(rest, tokens, "", nil)
  end

  defp do_tokenize(<<c, rest::binary>>, tokens, current, nil) when c in [?\s, ?\t] do
    do_tokenize(rest, [current | tokens], "", nil)
  end

  # Regular character
  defp do_tokenize(<<c, rest::binary>>, tokens, current, quote_char) do
    do_tokenize(rest, tokens, current <> <<c>>, quote_char)
  end
end
