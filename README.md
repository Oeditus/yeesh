<img src="https://raw.githubusercontent.com/Oeditus/yeesh/v0.1.0/stuff/img/logo-128x128.jpg" alt="Yeesh" width="128" align="right">

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
npm install --prefix assets @xterm/xterm @xterm/addon-fit @xterm/addon-web-links lit
```

Import the Yeesh terminal web component into your `app.js`:

```javascript
import "phoenix-colocated/yeesh"
```

Insert the import line high above in the `app.js`, ideally immediately after the
`import {LiveSocket} from "phoenix_live_view"` line.

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

By default, only the `help` built-in command is registered.

## Built-in Commands

Yeesh ships with several built-in commands: `help`, `clear`, `history`, `echo`,
`env`, and `elixir` (sandboxed REPL). The `:builtins` assign controls which of
these are available:

| Value | Effect |
|---|---|
| `:help` (default) | Only the `help` command |
| `:all` | All built-in commands |
| `:none` | No built-in commands at all |
| list of modules | Exactly those modules |

```elixir
<%!-- All built-ins --%>
<.live_component
  module={Yeesh.Live.TerminalComponent}
  id="terminal"
  builtins={:all}
/>

<%!-- Only help + history --%>
<.live_component
  module={Yeesh.Live.TerminalComponent}
  id="terminal"
  builtins={[Yeesh.Builtin.Help, Yeesh.Builtin.History]}
/>

<%!-- No built-ins at all --%>
<.live_component
  module={Yeesh.Live.TerminalComponent}
  id="terminal"
  builtins={:none}
  commands={[MyApp.Commands.Status]}
/>
```

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
  builtins={:all}
  commands={[MyApp.Commands.Deploy]}
/>
```

## Command Grouping

The `help` command groups output automatically based on command names.
Command names may contain dots (`.`), dashes (`-`), and underscores (`_`) as
separators. The text before the first separator determines the group:

- **Built-in commands** are always grouped under "Built-in".
- **Commands that implement `group/0`** use the returned string as the group
  name (takes precedence over automatic grouping).
- **Commands without a separator** (e.g. `deploy`) appear under "Generic".
- **Commands with a separator** are grouped by their prefix, capitalized.
  For example, `db.migrate`, `db-seed`, and `db_status` all appear under "Db".

Groups are displayed in order: Built-in first, Generic second, then custom
groups alphabetically.

### Explicit groups

Implement the optional `group/0` callback to override automatic grouping:

```elixir
defmodule MyApp.Commands.Migrate do
  @behaviour Yeesh.Command

  @impl true
  def name, do: "db.migrate"

  @impl true
  def group, do: "Database"

  @impl true
  def description, do: "Run database migrations"

  @impl true
  def usage, do: "db.migrate [--step N]"

  @impl true
  def execute(_args, session), do: {:ok, "Migrated", session}
end
```

Without `group/0`, this command would appear under "Db" (derived from the
name prefix). With it, it appears under "Database" instead.

### Example output

```
Built-in:
  help            Show available commands or help for a specific command
  clear           Clear the terminal screen

Generic:
  deploy          Deploy the application

Database:
  db.migrate      Run database migrations
  db.seed         Seed the database

Sys:
  sys.info        Show system information
  sys.health      Run health checks
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
- `:builtins` -- which built-in commands to register: `:all`, `:none`, `:help`,
  or a list of builtin modules (default: `:help`)
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
