defmodule Oauth2Server.Application do
  @moduledoc false

  use Application

  # Capture env at compile time (Mix is not available at runtime in releases)
  @env Mix.env()

  @impl true
  def start(_type, _args) do
    children =
      if @env == :test do
        # Don't start Repo in test - OAuth clients are in-memory
        [
          {Phoenix.PubSub, name: Oauth2Server.PubSub},
          Oauth2ServerWeb.Endpoint
        ]
      else
        [
          Oauth2Server.Repo,
          {Phoenix.PubSub, name: Oauth2Server.PubSub},
          Oauth2ServerWeb.Endpoint
        ]
      end

    opts = [strategy: :one_for_one, name: Oauth2Server.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    Oauth2ServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
