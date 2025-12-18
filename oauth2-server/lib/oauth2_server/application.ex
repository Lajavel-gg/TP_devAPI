defmodule Oauth2Server.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Oauth2Server.Repo,
      {Phoenix.PubSub, name: Oauth2Server.PubSub},
      Oauth2ServerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Oauth2Server.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    Oauth2ServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
