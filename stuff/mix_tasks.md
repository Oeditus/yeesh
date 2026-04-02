# Running Mix Tasks

Yeesh can execute Mix tasks directly in the browser terminal. Both
non-interactive tasks (run-to-completion) and interactive tasks
(REPL-style loops with `IO.gets`) are supported transparently --
no modifications to the Mix task source code are required.

## How it works

When you run a Mix task through Yeesh, the task is spawned in a
separate BEAM process whose **group leader** is replaced with a
custom Erlang IO protocol server (`Yeesh.IOServer`). This
intercepts all `IO.puts`, `IO.gets`, `IO.write`, and
`Mix.shell()` calls, bridging them to the LiveView terminal:

- `IO.puts`/`IO.write` output is buffered and sent to the browser
- `IO.gets` pauses the task and waits for user input from xterm.js
- Output newlines are automatically converted to `\r\n` for xterm.js

## The `mix` builtin command

The `mix` command is automatically available in every Yeesh terminal
(in dev/test environments where Mix is loaded):

```
$ mix                              # list available Mix tasks
$ mix deps.tree                    # run a non-interactive task
$ mix ragex.chat --skip-analysis   # run an interactive task
```

### Non-interactive tasks

Tasks that produce output and exit without calling `IO.gets` are
handled synchronously. Output appears in the terminal when the
task finishes:

```
$ mix yeesh_test.echo hello world
hello world
```

### Interactive tasks

Tasks that call `IO.gets` (directly or via `IO.read`, `Mix.shell().prompt/1`,
etc.) enter **mix task mode**. The terminal prompt changes to match
the task's prompt, and each line you type is forwarded to the task:

```
$ mix ragex.chat
Ragex Chat
Project: my_project
...
Type your question or /help for commands.

ragex> What does the User module do?
The User module handles authentication and ...

ragex> /quit
Goodbye!
$
```

Type `exit` at any point to forcibly terminate the task and return
to the normal shell.

## Wrapping tasks as named commands

If you want a Mix task to appear as a first-class terminal command
(without the `mix` prefix), use the `Yeesh.MixCommand` macro:

```elixir
defmodule MyApp.YeeshCommands.Chat do
  use Yeesh.MixCommand,
    task: "ragex.chat",
    name: "chat",
    description: "Interactive codebase Q&A",
    default_args: ["--skip-analysis"]
end
```

Then register it on the terminal component:

```elixir
<.live_component
  module={Yeesh.Live.TerminalComponent}
  id="terminal"
  commands={[MyApp.YeeshCommands.Chat]}
/>
```

Now users can type `chat` instead of `mix ragex.chat --skip-analysis`:

```
$ chat
Ragex Chat
...
```

### Macro options

| Option          | Required | Description                                        |
|-----------------|----------|----------------------------------------------------|
| `:task`         | yes      | Mix task name (e.g. `"ragex.chat"`)                |
| `:name`         | yes      | Command name in the terminal                       |
| `:description`  | no       | Short description for `help` output                |
| `:usage`        | no       | Usage string (auto-generated if omitted)           |
| `:default_args` | no       | Arguments prepended to user input (default: `[]`)  |

User arguments are appended after `:default_args`, so:

```elixir
default_args: ["--verbose"]
```

Running `chat --path /tmp` results in the task receiving
`["--verbose", "--path", "/tmp"]`.

## Architecture overview

```
Browser (xterm.js)
    |
    | yeesh:input / yeesh:output events
    v
TerminalComponent (LiveComponent)
    |
    | Executor.execute/2
    v
Executor (:mix_task mode)
    |
    | IOServer.provide_input_and_wait/3
    v
IOServer (custom group leader)
    ^
    | IO protocol messages
    |
Mix Task Process
    (IO.puts, IO.gets, Mix.shell)
```

The `Yeesh.IOServer` implements the
[Erlang IO protocol](https://www.erlang.org/doc/apps/stdlib/io_protocol.html)
and handles `put_chars`, `get_line`, `get_until`, `get_chars`,
`getopts`, `setopts`, and batched `requests`.

## Known limitations

### No live-streaming output

Output is buffered until the task calls `IO.gets` or exits.
Animations (spinners, progress bars, `Owl.LiveScreen`) won't
render progressively -- you see the final output instead.
Streaming support is planned for a future milestone.

### Mix availability

The `mix` command and `Yeesh.MixCommand` macro require the `Mix`
module, which is only available in `:dev` and `:test` environments.
In production releases, these modules are not compiled. If you need
task-like functionality in production, implement the `Yeesh.Command`
behaviour directly.

### Unsandboxed execution

Unlike the `elixir` REPL command (which runs through Dune), Mix tasks
execute without sandboxing. Only expose tasks you trust -- a malicious
task could modify files, access the network, or crash the VM.

### Task idempotency

`Mix.Task.rerun/2` is used internally to allow repeated execution.
Dependency tasks (like `app.start`) are not re-run if already
completed.

### Global `Mix.shell`

During Mix task execution, `Mix.shell` is temporarily set to
`Yeesh.MixShell`, which routes `Mix.shell().error/1` through the
group leader instead of `:standard_error`. This is a VM-global
setting. Since `Yeesh.MixShell` routes through the per-process
group leader, concurrent terminals work correctly, but the original
shell module is replaced for the duration of the task.
