defmodule Oauth2ServerWeb.HealthController do
  use Oauth2ServerWeb, :controller

  def index(conn, _params) do
    json(conn, %{status: "ok", service: "oauth2-server-elixir"})
  end
end
