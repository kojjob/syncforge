defmodule Syncforge.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SyncforgeWeb.Telemetry,
      Syncforge.Repo,
      {DNSCluster, query: Application.get_env(:syncforge, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Syncforge.PubSub},
      # Start a worker by calling: Syncforge.Worker.start_link(arg)
      # {Syncforge.Worker, arg},
      # Start to serve requests, typically the last entry
      SyncforgeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Syncforge.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SyncforgeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
