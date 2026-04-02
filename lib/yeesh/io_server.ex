defmodule Yeesh.IOServer do
  @moduledoc """
  Custom Erlang IO protocol server for intercepting Mix task I/O.

  Acts as a group leader for spawned Mix task processes, transparently
  capturing all `IO.puts`/`IO.gets`/`IO.write` calls. Output is buffered
  internally; input requests block the task until the caller provides
  input via `provide_input_and_wait/3`.

  This module implements the Erlang IO protocol
  ([`io(3)`](https://www.erlang.org/doc/apps/stdlib/io_protocol.html))
  as a GenServer. It handles the following IO requests:

    * `{:put_chars, encoding, chars}` -- buffers output
    * `{:put_chars, encoding, mod, fun, args}` -- evaluates and buffers
    * `{:get_line, encoding, prompt}` -- blocks until input is provided
    * `{:get_until, encoding, prompt, mod, fun, args}` -- same as get_line
    * `{:get_chars, encoding, prompt, count}` -- same as get_line
    * `:getopts` / `{:setopts, opts}` -- encoding options
    * `{:requests, list}` -- batched requests

  Output newlines are normalized from `\\n` to `\\r\\n` for xterm.js
  compatibility when the buffer is flushed.

  ## Lifecycle

  1. Started by `Yeesh.MixRunner` before spawning the task process.
  2. The task process's group leader is set to this server.
  3. Caller uses `start_and_wait/2` to block until the task either
     requests input (`IO.gets`) or exits.
  4. For interactive tasks, caller repeatedly calls
     `provide_input_and_wait/3` to feed lines and collect output.
  5. When the task exits, the server reports `:done`.
  """

  use GenServer

  @default_timeout 30_000

  @typedoc "Buffered output text with task status and optional prompt."
  @type wait_result ::
          {output :: String.t(), :waiting, prompt :: String.t()}
          | {output :: String.t(), :done}

  # -- State ------------------------------------------------------------------

  defstruct output_buffer: [],
            pending_input: nil,
            waiter: nil,
            task_pid: nil,
            task_ref: nil,
            prompt: "",
            status: :idle

  # -- Public API -------------------------------------------------------------

  @doc """
  Starts the IO server.

  ## Options

    * `:name` -- optional GenServer name
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    gen_opts = if name = opts[:name], do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, gen_opts)
  end

  @doc """
  Registers the task process to monitor and begins intercepting its I/O.

  Must be called after `start_link/1` and before `start_and_wait/2`.
  """
  @spec monitor_task(GenServer.server(), pid()) :: :ok
  def monitor_task(server, task_pid) do
    GenServer.call(server, {:monitor_task, task_pid})
  end

  @doc """
  Blocks until the monitored task either calls `IO.gets` or exits.

  Returns `{output, :waiting, prompt}` if the task is waiting for input,
  or `{output, :done}` if the task finished.

  ## Options

    * `:timeout` -- call timeout in milliseconds (default: `#{@default_timeout}`)
  """
  @spec start_and_wait(GenServer.server(), keyword()) :: wait_result()
  def start_and_wait(server, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    GenServer.call(server, :start_and_wait, timeout)
  end

  @doc """
  Provides a line of input to the blocked task and waits for the next
  input request or task exit.

  The input string is delivered to the pending `IO.gets` call (with a
  trailing newline appended). The caller then blocks until the task
  either calls `IO.gets` again or terminates.

  Returns `{output, :waiting, prompt}` or `{output, :done}`.

  ## Options

    * `:timeout` -- call timeout in milliseconds (default: `#{@default_timeout}`)
  """
  @spec provide_input_and_wait(GenServer.server(), String.t(), keyword()) :: wait_result()
  def provide_input_and_wait(server, input, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    GenServer.call(server, {:provide_input, input}, timeout)
  end

  @doc """
  Stops the IO server, killing the monitored task if still alive.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(server) do
    GenServer.stop(server, :normal)
  end

  # -- GenServer callbacks ----------------------------------------------------

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:monitor_task, task_pid}, _from, state) do
    ref = Process.monitor(task_pid)
    {:reply, :ok, %{state | task_pid: task_pid, task_ref: ref, status: :running}}
  end

  def handle_call(:start_and_wait, _from, %{status: :done} = state) do
    # Task already finished before we started waiting
    {:reply, {flush_buffer(state), :done}, %{state | output_buffer: []}}
  end

  def handle_call(:start_and_wait, _from, %{pending_input: {_, _}} = state) do
    # Task already called IO.gets before we started waiting
    {:reply, {flush_buffer(state), :waiting, state.prompt}, %{state | output_buffer: []}}
  end

  def handle_call(:start_and_wait, from, state) do
    {:noreply, %{state | waiter: from}}
  end

  def handle_call({:provide_input, input}, from, %{pending_input: {io_from, reply_as}} = state)
      when state.status != :done do
    # Unblock the task's IO.gets with the user's input
    send(io_from, {:io_reply, reply_as, input <> "\n"})

    {:noreply,
     %{state | pending_input: nil, waiter: from, output_buffer: [], prompt: "", status: :running}}
  end

  def handle_call({:provide_input, _input}, _from, %{status: :done} = state) do
    {:reply, {flush_buffer(state), :done}, state}
  end

  def handle_call({:provide_input, _input}, _from, state) do
    # No pending input request -- task isn't waiting for input
    {:reply, {flush_buffer(state), :done}, %{state | output_buffer: []}}
  end

  # -- IO protocol handling ---------------------------------------------------

  @impl true
  def handle_info({:io_request, from, reply_as, request}, state) do
    handle_io_request(request, from, reply_as, state)
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{task_ref: ref} = state) do
    new_state = %{state | status: :done, task_pid: nil, task_ref: nil, pending_input: nil}

    if state.waiter do
      GenServer.reply(state.waiter, {flush_buffer(state), :done})
      {:noreply, %{new_state | waiter: nil, output_buffer: []}}
    else
      {:noreply, new_state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    # Kill the task process if still alive
    if state.task_pid && Process.alive?(state.task_pid) do
      Process.exit(state.task_pid, :kill)
    end

    :ok
  end

  # -- IO request dispatchers -------------------------------------------------

  # put_chars: buffer output, reply :ok immediately
  defp handle_io_request({:put_chars, _encoding, chars}, from, reply_as, state) do
    send(from, {:io_reply, reply_as, :ok})
    {:noreply, %{state | output_buffer: [state.output_buffer, chars]}}
  end

  defp handle_io_request({:put_chars, encoding, mod, fun, args}, from, reply_as, state) do
    chars =
      try do
        apply(mod, fun, args)
      rescue
        _ -> ""
      end

    handle_io_request({:put_chars, encoding, chars}, from, reply_as, state)
  end

  # get_line / get_until / get_chars: block until input is provided
  defp handle_io_request({:get_line, _encoding, prompt}, from, reply_as, state) do
    handle_input_request(from, reply_as, prompt, state)
  end

  defp handle_io_request(
         {:get_until, _encoding, prompt, _mod, _fun, _args},
         from,
         reply_as,
         state
       ) do
    handle_input_request(from, reply_as, prompt, state)
  end

  defp handle_io_request({:get_chars, _encoding, prompt, _count}, from, reply_as, state) do
    handle_input_request(from, reply_as, prompt, state)
  end

  # Options
  defp handle_io_request(:getopts, from, reply_as, state) do
    send(from, {:io_reply, reply_as, {:ok, [encoding: :unicode]}})
    {:noreply, state}
  end

  defp handle_io_request({:setopts, _opts}, from, reply_as, state) do
    send(from, {:io_reply, reply_as, :ok})
    {:noreply, state}
  end

  # Batched requests
  defp handle_io_request({:requests, requests}, from, reply_as, state) do
    {last_reply, new_state} = process_batch(requests, from, :ok, state)
    send(from, {:io_reply, reply_as, last_reply})
    {:noreply, new_state}
  end

  # Unknown request
  defp handle_io_request(_request, from, reply_as, state) do
    send(from, {:io_reply, reply_as, {:error, :request}})
    {:noreply, state}
  end

  # -- Internal helpers -------------------------------------------------------

  defp handle_input_request(from, reply_as, prompt, state) do
    prompt_str = to_string(prompt)

    if state.waiter do
      output = flush_buffer(state)
      GenServer.reply(state.waiter, {output, :waiting, prompt_str})

      {:noreply,
       %{
         state
         | pending_input: {from, reply_as},
           waiter: nil,
           output_buffer: [],
           prompt: prompt_str,
           status: :waiting
       }}
    else
      # No waiter yet (shouldn't happen in normal flow), store pending
      {:noreply,
       %{
         state
         | pending_input: {from, reply_as},
           prompt: prompt_str,
           status: :waiting
       }}
    end
  end

  defp process_batch([], _from, last_reply, state) do
    {last_reply, state}
  end

  defp process_batch([request | rest], from, _last_reply, state) do
    case request do
      {:put_chars, _encoding, chars} ->
        new_state = %{state | output_buffer: [state.output_buffer, chars]}
        process_batch(rest, from, :ok, new_state)

      {:put_chars, _encoding, mod, fun, args} ->
        chars =
          try do
            apply(mod, fun, args)
          rescue
            _ -> ""
          end

        new_state = %{state | output_buffer: [state.output_buffer, chars]}
        process_batch(rest, from, :ok, new_state)

      _ ->
        # For non-put_chars in batch, just skip (input requests in batches are rare)
        process_batch(rest, from, :ok, state)
    end
  end

  defp flush_buffer(state) do
    state.output_buffer
    |> IO.iodata_to_binary()
    |> normalize_newlines()
  end

  @doc false
  @spec normalize_newlines(String.t()) :: String.t()
  def normalize_newlines(text) do
    String.replace(text, ~r/(?<!\r)\n/, "\r\n")
  end
end
