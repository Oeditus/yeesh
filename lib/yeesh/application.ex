defmodule Yeesh.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Yeesh.Registry,
      {DynamicSupervisor, name: Yeesh.SessionSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: Yeesh.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
