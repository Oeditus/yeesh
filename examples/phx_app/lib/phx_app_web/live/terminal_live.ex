defmodule PhxAppWeb.TerminalLive do
  use PhxAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    commands = [
      PhxApp.Commands.Fibonacci,
      PhxApp.Commands.Cowsay,
      PhxApp.Commands.Sysinfo
    ]

    {:ok, assign(socket, demo_commands: commands)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex flex-col items-center gap-6 w-full max-w-4xl mx-auto">
        <div class="text-center space-y-2">
          <h1 class="text-3xl font-bold tracking-tight">Yeesh Demo</h1>
          <p class="text-base-content/60 text-sm">
            A sandboxed terminal in your browser. Try <code class="px-1.5 py-0.5 rounded bg-base-300 text-sm font-mono">help</code>, <code class="px-1.5 py-0.5 rounded bg-base-300 text-sm font-mono">cowsay hello</code>, <code class="px-1.5 py-0.5 rounded bg-base-300 text-sm font-mono">sysinfo</code>, <code class="px-1.5 py-0.5 rounded bg-base-300 text-sm font-mono">fib 30</code>, or
            <code class="px-1.5 py-0.5 rounded bg-base-300 text-sm font-mono">elixir</code>
            to enter the Elixir REPL.
          </p>
        </div>

        <div
          id="terminal-container"
          class="w-full rounded-xl overflow-hidden shadow-2xl border border-base-300"
          style="height: 480px;"
        >
          <.live_component
            module={Yeesh.Live.TerminalComponent}
            id="yeesh-demo"
            commands={@demo_commands}
            prompt="yeesh> "
            theme={:default}
          />
        </div>

        <div class="flex flex-wrap gap-2 justify-center text-xs text-base-content/40">
          <span class="px-2 py-1 rounded-full bg-base-200">Tab: autocomplete</span>
          <span class="px-2 py-1 rounded-full bg-base-200">Up/Down: history</span>
          <span class="px-2 py-1 rounded-full bg-base-200">Ctrl+C: interrupt</span>
          <span class="px-2 py-1 rounded-full bg-base-200">Ctrl+L: clear</span>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
