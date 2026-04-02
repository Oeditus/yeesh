# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project overview

Yeesh is an Elixir library (not a standalone app) that provides a LiveView terminal component with sandboxed command execution. It renders an xterm.js-based terminal in the browser and communicates with a Phoenix LiveComponent over LiveView events. Elixir evaluation is sandboxed via [Dune](https://hexdocs.pm/dune). The library is published to Hex as `:yeesh`.

## Build and development commands

```
mix deps.get              # fetch dependencies
mix compile               # compile
mix test                  # run all tests
mix test test/yeesh/executor_test.exs          # run a single test file
mix test test/yeesh/executor_test.exs:7        # run a single test by line
mix format                # format code
mix credo --strict        # static analysis
mix dialyzer              # type checking (PLT stored in .dialyzer/)
mix quality               # alias: format + credo --strict + dialyzer
mix quality.ci            # CI variant: format --check-formatted + credo --strict + dialyzer
mix coveralls.html        # test coverage (ExCoveralls, run under MIX_ENV=test)
```

JS assets for consumers live in `assets/` and require npm peer dependencies (`@xterm/xterm`, `@xterm/addon-fit`, `@xterm/addon-web-links`). The library itself has no JS build step.

## Architecture

### Supervision tree (Yeesh.Application)

`Yeesh.Registry` (GenServer, ETS-backed command registry) and `Yeesh.SessionSupervisor` (DynamicSupervisor for per-terminal sessions) start under `Yeesh.Supervisor`.

### Request lifecycle

1. **TerminalComponent** (`Yeesh.Live.TerminalComponent`) -- Phoenix LiveComponent. On mount it starts a `Session` via `DynamicSupervisor`, registers consumer commands, and renders a `<div>` with `phx-hook="YeeshTerminal"`.
2. **JS hook** (`assets/js/yeesh/hook.js`) -- xterm.js instance handles local line editing, then pushes events (`yeesh:input`, `yeesh:complete`, `yeesh:history_prev/next`, `yeesh:interrupt`) to the LiveComponent.
3. **Executor** (`Yeesh.Executor`) -- Parses input (tokenizer supports quoting), looks up the command in the Registry, and dispatches synchronously. In `:elixir_repl` mode, input goes to `Sandbox.eval/2` instead.
4. **Registry** (`Yeesh.Registry`) -- ETS table (`public`, `read_concurrency: true`). Builtins are registered at app start; consumer commands are added on component mount.
5. **Session** (`Yeesh.Session`) -- GenServer holding per-terminal state: history, env vars, mode (`:normal` | `:elixir_repl`), Dune session, context map. One session per terminal instance.
6. **Sandbox** (`Yeesh.Sandbox`) -- Wraps `Dune.Session` for safe, stateful Elixir evaluation with configurable limits.

### Command behaviour

Custom commands implement `Yeesh.Command`: callbacks `name/0`, `description/0`, `usage/0`, `execute/2`, and optional `completions/2`. `execute/2` returns `{:ok, output, session}` or `{:error, reason, session}`.

Builtins live in `lib/yeesh/builtin/` -- `help`, `clear`, `echo`, `env`, `history`, `elixir` (REPL).

### Output

`Yeesh.Output` provides ANSI escape helpers (`red/1`, `bold/1`, `error/1`, etc.) that xterm.js renders on the client. Terminal newlines must be `\r\n`.

### Compile paths

`test/support/` is included in `:dev` and `:test` elixirc_paths.

## Key conventions

- Command execution is synchronous (async streaming planned for Milestone 3).
- All terminal output uses `\r\n` line endings (xterm.js requirement).
- The `Yeesh.Command.completions/2` callback is optional.
- Session state is always threaded through commands via the return tuple; never mutate session outside `Session.update/2`.
- The `examples/phx_app/` directory contains a full Phoenix app demonstrating integration.

## Dependencies

Core runtime: `phoenix_live_view`, `phoenix_html`, `jason`, `dune`.
Dev/test only: `ex_doc`, `excoveralls`, `credo`, `dialyxir`.
