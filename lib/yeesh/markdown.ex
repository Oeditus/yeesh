defmodule Yeesh.Markdown do
  @moduledoc """
  Converts Markdown to ANSI-escaped terminal output for xterm.js.

  Delegates to `Marcli` with `\\r\\n` line endings as required
  by the xterm.js terminal emulator.

  ## Example

      output = Yeesh.Markdown.render("# Hello\\n\\nSome **bold** text.")
  """

  @doc """
  Renders a Markdown string as ANSI-escaped terminal output
  with `\\r\\n` line endings for `xterm.js`.

  Requires `{:marcli, "~> 0.3"}` dependency.
  """
  @spec render(String.t()) :: String.t()
  def render(markdown) when is_binary(markdown) do
    # credo:disable-for-lines:3
    if Code.ensure_loaded?(Marcli),
      do: apply(Marcli, :render, [markdown, [newline: "\r\n"]]),
      else: markdown
  end
end
