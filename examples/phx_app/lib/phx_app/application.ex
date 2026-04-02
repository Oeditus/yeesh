defmodule PhxApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PhxAppWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:phx_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PhxApp.PubSub},
      # Start a worker by calling: PhxApp.Worker.start_link(arg)
      # {PhxApp.Worker, arg},
      # Start to serve requests, typically the last entry
      PhxAppWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhxApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhxAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
