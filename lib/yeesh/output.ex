defmodule Yeesh.Output do
  @moduledoc """
  ANSI output formatting helpers for terminal commands.

  Commands can use these helpers to produce colored and styled output.
  xterm.js renders the ANSI escape sequences on the client.

  ## Example

      alias Yeesh.Output

      output = Output.green("Success: ") <> Output.bold("deployed v1.2.3")
  """

  @reset "\e[0m"
  @bold "\e[1m"
  @dim "\e[2m"
  @italic "\e[3m"
  @underline "\e[4m"

  @red "\e[31m"
  @green "\e[32m"
  @yellow "\e[33m"
  @blue "\e[34m"
  @magenta "\e[35m"
  @cyan "\e[36m"
  @white "\e[37m"
  @gray "\e[90m"

  @doc "Wraps text in bold."
  @spec bold(String.t()) :: String.t()
  def bold(text), do: @bold <> text <> @reset

  @doc "Wraps text in dim style."
  @spec dim(String.t()) :: String.t()
  def dim(text), do: @dim <> text <> @reset

  @doc "Wraps text in italic."
  @spec italic(String.t()) :: String.t()
  def italic(text), do: @italic <> text <> @reset

  @doc "Wraps text in underline."
  @spec underline(String.t()) :: String.t()
  def underline(text), do: @underline <> text <> @reset

  @doc "Colors text red."
  @spec red(String.t()) :: String.t()
  def red(text), do: @red <> text <> @reset

  @doc "Colors text green."
  @spec green(String.t()) :: String.t()
  def green(text), do: @green <> text <> @reset

  @doc "Colors text yellow."
  @spec yellow(String.t()) :: String.t()
  def yellow(text), do: @yellow <> text <> @reset

  @doc "Colors text blue."
  @spec blue(String.t()) :: String.t()
  def blue(text), do: @blue <> text <> @reset

  @doc "Colors text magenta."
  @spec magenta(String.t()) :: String.t()
  def magenta(text), do: @magenta <> text <> @reset

  @doc "Colors text cyan."
  @spec cyan(String.t()) :: String.t()
  def cyan(text), do: @cyan <> text <> @reset

  @doc "Colors text white."
  @spec white(String.t()) :: String.t()
  def white(text), do: @white <> text <> @reset

  @doc "Colors text gray."
  @spec gray(String.t()) :: String.t()
  def gray(text), do: @gray <> text <> @reset

  @doc "Resets all ANSI formatting."
  @spec reset :: String.t()
  def reset, do: @reset

  @doc "Formats an error message (red, prefixed with 'error:')."
  @spec error(String.t()) :: String.t()
  def error(message), do: red("error: ") <> message

  @doc "Formats a warning message (yellow, prefixed with 'warning:')."
  @spec warning(String.t()) :: String.t()
  def warning(message), do: yellow("warning: ") <> message
end
