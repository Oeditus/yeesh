# Yeesh

A LiveView terminal component with sandboxed command execution.

Yeesh provides a browser-based CLI with fish/zsh-like features (tab completion,
command history, prompt customization) and Dune-powered sandboxed Elixir evaluation.

## Features

- **xterm.js-powered terminal** -- full terminal emulation in the browser with
  GPU-accelerated rendering, ANSI colors, scrollback, selection, and web links
- **Command behaviour** -- define custom commands with a simple behaviour
- **Tab completion** -- command name completion out of the box
- **Command history** -- up/down arrow navigation through previous commands
- **Sandboxed Elixir REPL** -- evaluate Elixir code safely via Dune, with
  configurable allowlists, memory/reduction limits, and atom leak prevention
- **ANSI output helpers** -- `Yeesh.Output` provides colored/styled output
- **Per-session state** -- each terminal instance gets isolated history,
  environment variables, and Dune session state

## Installation

Add `yeesh` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:yeesh, "~> 0.1.0"}
  ]
end
```

Install the JavaScript dependencies:

```bash
npm install --prefix assets @xterm/xterm @xterm/addon-fit @xterm/addon-web-links
```

Register the hook in your `app.js`:

```javascript
import { YeeshTerminal } from "../../deps/yeesh/assets/js/yeesh/hook.js"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { YeeshTerminal }
})
```

## Quick Start

Add the terminal component to any LiveView:

```elixir
<.live_component
  module={Yeesh.Live.TerminalComponent}
  id="terminal"
  commands={[]}
  prompt="app> "
/>
```

This gives you a working terminal with all built-in commands: `help`, `clear`,
`history`, `echo`, `env`, and `elixir` (sandboxed REPL).

## Custom Commands

Implement the `Yeesh.Command` behaviour:

```elixir
defmodule MyApp.Commands.Deploy do
  @behaviour Yeesh.Command

  @impl true
  def name, do: "deploy"

  @impl true
  def description, do: "Deploy the application"

  @impl true
  def usage, do: "deploy [environment]"

  @impl true
  def execute([], session), do: {:error, "specify an environment", session}

  def execute([env], session) do
    # Your deployment logic here
    {:ok, "Deployed to #{env}", session}
  end
end
```

Register it in the component:

```elixir
<.live_component
  module={Yeesh.Live.TerminalComponent}
  id="terminal"
  commands={[MyApp.Commands.Deploy]}
/>
```

## Elixir REPL

The built-in `elixir` command provides a sandboxed Elixir evaluation
environment powered by [Dune](https://hexdocs.pm/dune):

```
$ elixir 1 + 2
3
$ elixir
Entering sandboxed Elixir REPL (powered by Dune).
Type 'exit' to return to the shell.
iex> x = 42
42
iex> x * 2
84
iex> exit
$
```

Variables persist within the session. Dangerous functions (file system,
network, code loading) are restricted by Dune's allowlist.

Configure the sandbox:

```elixir
<.live_component
  module={Yeesh.Live.TerminalComponent}
  id="terminal"
  sandbox_opts={[timeout: 10_000, max_reductions: 100_000]}
/>
```

## Configuration

- `:prompt` -- prompt string (default: `"$ "`)
- `:commands` -- list of command modules (default: `[]`)
- `:theme` -- terminal theme, `:default` or `:light` (default: `:default`)
- `:context` -- arbitrary map passed to commands (default: `%{}`)
- `:sandbox_opts` -- Dune sandbox configuration (default: `[]`)

## Execution Model

Command execution is currently **synchronous** -- the LiveView process blocks
until the command completes (with a configurable timeout, default 5s).

Async streaming execution is planned for **Milestone 3**.

## Roadmap

- **Milestone 2**: Argument-level tab completion, fish-style auto-suggestions,
  syntax highlighting, Ctrl+R history search, aliases, theming,
  OS command passthrough (explicit opt-in with allowlist)
- **Milestone 3**: Async streaming execution for long-running commands,
  pipe support, output paging, session persistence

## License

MIT
