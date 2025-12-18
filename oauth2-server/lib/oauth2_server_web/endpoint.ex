defmodule Oauth2ServerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :oauth2_server

  @session_options [
    store: :cookie,
    key: "_oauth2_server_key",
    signing_salt: "oauth2_signing_salt",
    same_site: "Lax"
  ]

  plug Plug.Static,
    at: "/",
    from: :oauth2_server,
    gzip: false,
    only: Oauth2ServerWeb.static_paths()

  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug CORSPlug,
    origin: ["http://localhost:8080", "http://127.0.0.1:8080"],
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    headers: ["Authorization", "Content-Type", "Accept"]

  plug Oauth2ServerWeb.Router
end
