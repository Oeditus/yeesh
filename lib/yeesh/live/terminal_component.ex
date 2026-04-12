defmodule Yeesh.Live.TerminalComponent do
  @moduledoc """
  LiveView component that renders an interactive terminal in the browser.

  ## Usage

      <.live_component
        module={Yeesh.Live.TerminalComponent}
        id="my-terminal"
        commands={[MyApp.Commands.Deploy]}
        prompt="app> "
        theme={:dark}
        context={%{user_id: @current_user.id}}
      />

  ## Assigns

    - `:id` (required) - unique identifier for this terminal instance
    - `:commands` - list of command modules to register (default: `[]`)
    - `:prompt` - prompt string (default: `"$ "`)
    - `:theme` - terminal theme (default: `:default`)
    - `:welcome_message` - welcome message (default: the Yeesh welcome message)
    - `:resize_event` - `CustomEvent` name to dispatch on resize to fit if defined (default: nil)
    - `:context` - arbitrary map passed through to commands (default: `%{}`)
    - `:session_opts` - additional session options (default: `[]`)
    - `:sandbox_opts` - Dune sandbox configuration (default: `[]`)

  ## Events

  The component communicates with the JS hook via `push_event`/`handle_event`:

    - `"yeesh:input"` - user submitted a command line
    - `"yeesh:complete"` - tab completion request
    - `"yeesh:history_prev"` - up arrow / Ctrl+P
    - `"yeesh:history_next"` - down arrow / Ctrl+N
    - `"yeesh:history_search"` - Ctrl+R reverse incremental search
    - `"yeesh:interrupt"` - Ctrl+C
    - `"yeesh:output"` - pushed to client with command output
    - `"yeesh:completion"` - pushed to client with completions
    - `"yeesh:search_result"` - pushed to client with search match
    - `"yeesh:prompt"` - pushed to client with new prompt
  """

  use Phoenix.LiveComponent

  alias Yeesh.{Completion, Executor, Registry, Session}

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      socket
      |> assign( :final_prompt, get_prompt( socket.assigns))
      |> assign_new( :session_pid, fn -> nil end)
      |> assign_new( :commands, fn -> nil end)
      |> assign_new( :theme, fn -> :default end)
      |> assign_new( :resize_event, fn -> nil end)
      |> assign_new( :welcome_message, fn ->
        "\x1b[1;36mYeesh\x1b[0m - sandboxed terminal (type \x1b[1mhelp\x1b[0m for commands)"
      end)

    socket =
      if socket.assigns[:session_pid] == nil and connected?(socket) do
        session_opts =
          Keyword.merge(
            [
              prompt: assigns[:prompt] || "$ ",
              sandbox_opts: assigns[:sandbox_opts] || [],
              context: assigns[:context] || %{}
            ],
            assigns[:session_opts] || []
          )

        {:ok, pid} = Session.start(session_opts)

        # Register consumer commands
        commands = assigns[:commands] || []
        Registry.register_all(commands)

        assign(socket, session_pid: pid)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <yeesh-terminal
      id={@id}
      theme={@theme}
      welcome={@welcome_message}
      prompt={@final_prompt}
      commands={Jason.encode!(Registry.list())}
      resize-event={@resize_event}
      phx-update="ignore"
    />
    """
  end

  @impl true
  def handle_event("yeesh:input", %{"input" => input}, socket) do
    if session_pid = socket.assigns[:session_pid] do
      {output, _session} = Executor.execute(input, session_pid)
      prompt = Session.get_prompt(session_pid)

      socket =
        socket
        |> push_event("yeesh:prompt", %{prompt: prompt})
        |> push_event("yeesh:output", %{output: output})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("yeesh:complete", %{"input" => input, "cursor" => cursor}, socket) do
    if session_pid = socket.assigns[:session_pid] do
      session = Session.get_state(session_pid)
      {matches, replacement} = Completion.complete(input, cursor, session)

      socket =
        push_event(socket, "yeesh:completion", %{
          matches: matches,
          replacement: replacement
        })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("yeesh:history_prev", params, socket) do
    prefix = params["prefix"]

    if session_pid = socket.assigns[:session_pid] do
      case Session.history_prev(session_pid, prefix) do
        {:ok, entry} ->
          {:noreply, push_event(socket, "yeesh:history", %{entry: entry})}

        :empty ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("yeesh:history_next", params, socket) do
    prefix = params["prefix"]

    if session_pid = socket.assigns[:session_pid] do
      case Session.history_next(session_pid, prefix) do
        {:ok, entry} ->
          {:noreply, push_event(socket, "yeesh:history", %{entry: entry})}

        :end ->
          {:noreply, push_event(socket, "yeesh:history", %{entry: ""})}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("yeesh:history_search", %{"query" => query, "skip" => skip}, socket) do
    if session_pid = socket.assigns[:session_pid] do
      case Session.history_search(session_pid, query, skip) do
        {:ok, entry} ->
          {:noreply, push_event(socket, "yeesh:search_result", %{entry: entry, found: true})}

        :no_match ->
          {:noreply, push_event(socket, "yeesh:search_result", %{entry: "", found: false})}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("yeesh:interrupt", _params, socket) do
    if session_pid = socket.assigns[:session_pid] do
      Session.reset_history_index(session_pid)
      prompt = Session.get_prompt(session_pid)
      {:noreply, push_event(socket, "yeesh:prompt", %{prompt: prompt})}
    else
      {:noreply, socket}
    end
  end

  defp get_prompt(assigns) do
    if pid = assigns[:session_pid] do
      Session.get_prompt(pid)
    else
      assigns[:prompt] || "$ "
    end
  end
end
