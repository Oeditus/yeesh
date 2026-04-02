# PhxApp -- Yeesh Demo

A Phoenix application demonstrating the [Yeesh](https://hexdocs.pm/yeesh)
browser terminal component.

## Quick start

* Run `mix setup` to install and setup dependencies
* Start the server with `mix phx.server` or `iex -S mix phx.server`
* Visit [`localhost:4000`](http://localhost:4000)

## What to try

The terminal at `/` comes with several demo commands:

| Command | Type | Description |
|---------|------|-------------|
| `help` | builtin | List all available commands |
| `about` | custom command | Project info rendered from Markdown |
| `cowsay hello` | custom command | ASCII cow with a message |
| `sysinfo` | custom command | BEAM runtime information |
| `fib 30` | custom command | Fibonacci calculator |
| `elixir` | builtin | Sandboxed Elixir REPL (Dune) |
| `mix phx_app.stats` | Mix task (non-interactive) | BEAM stats via Mix |
| `mix phx_app.quiz` | Mix task (interactive) | Elixir trivia quiz |
| `quiz` | MixCommand wrapper | Same quiz, no `mix` prefix |
| `mix` | builtin | List all available Mix tasks |

### Mix task integration

The `mix` builtin command runs any Mix task from the browser terminal.
Non-interactive tasks run to completion; interactive tasks (those that
call `IO.gets`) enter a REPL mode where each line you type is forwarded
to the running task. Type `exit` to forcibly leave an interactive task.

`PhxApp.Commands.Quiz` demonstrates the `Yeesh.MixCommand` macro, which
wraps `mix phx_app.quiz` as a named `quiz` command:

```elixir
defmodule PhxApp.Commands.Quiz do
  use Yeesh.MixCommand,
    task: "phx_app.quiz",
    name: "quiz",
    description: "Play an interactive Elixir trivia quiz"
end
```

See the [Mix Tasks guide](https://hexdocs.pm/yeesh/mix_tasks.html) for
full documentation.
