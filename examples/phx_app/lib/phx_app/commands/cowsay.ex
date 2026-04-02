defmodule PhxApp.Commands.Cowsay do
  @behaviour Yeesh.Command

  @impl true
  def name, do: "cowsay"

  @impl true
  def description, do: "Make a cow say something"

  @impl true
  def usage, do: "cowsay <message>"

  @impl true
  def execute([], session) do
    execute(["moo!"], session)
  end

  def execute(args, session) do
    message = Enum.join(args, " ")
    border_len = String.length(message) + 2
    border = String.duplicate("-", border_len)

    cow = """
     #{border}
    < #{message} >
     #{border}
            \\   ^__^
             \\  (oo)\\_______
                (__)\\       )\\/\\
                    ||----w |
                    ||     ||\
    """

    {:ok, cow, session}
  end
end
