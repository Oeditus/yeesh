defmodule PhxApp.Commands.About do
  @behaviour Yeesh.Command

  @impl true
  def name, do: "about"

  @impl true
  def description, do: "Show project info (rendered from Markdown)"

  @impl true
  def usage, do: "about"

  @markdown """
  # Yeesh Demo

  A **sandboxed terminal** in your browser, powered by
  *Phoenix LiveView* and `xterm.js`.

  ## Features

  1. Tab completion and history
  2. Sandboxed Elixir REPL via Dune
  3. Custom commands and Mix task integration
  4. Markdown rendering with ANSI colors

  ## Built-in Commands

  - `help` -- list all available commands
  - `elixir` -- enter the sandboxed REPL
  - `clear` -- clear the screen
  - `mix <task>` -- run any Mix task

  ## Custom Commands

  > Commands implement the `Yeesh.Command` behaviour.
  > Each command defines `name/0`, `description/0`, and `execute/2`.

  Here is a minimal example:

  ```elixir
  defmodule MyApp.Commands.Ping do
    @behaviour Yeesh.Command

    def name, do: "ping"
    def description, do: "Responds with pong"
    def usage, do: "ping"
    def execute(_args, session), do: {:ok, "pong", session}
  end
  ```

  ---

  Built with **Elixir**, **Phoenix**, and ~~regret~~ *passion*.

  Learn more at [hexdocs.pm/yeesh](https://hexdocs.pm/yeesh).
  """

  @impl true
  def execute(_args, session) do
    {:ok, Yeesh.Markdown.render(@markdown), session}
  end
end
