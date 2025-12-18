defmodule Oauth2Server.Repo do
  use Ecto.Repo,
    otp_app: :oauth2_server,
    adapter: Ecto.Adapters.MyXQL
end
