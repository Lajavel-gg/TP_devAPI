# General application configuration
import Config

config :oauth2_server,
  ecto_repos: [Oauth2Server.Repo],
  generators: [timestamp_type: :utc_datetime]

# JWT configuration
config :oauth2_server, :jwt,
  secret_key: System.get_env("SECRET_KEY") || "super-secret-key-for-jwt-change-in-production-min-64-chars",
  token_ttl: 3600

# Configures the endpoint
config :oauth2_server, Oauth2ServerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [
    formats: [html: Oauth2ServerWeb.ErrorHTML, json: Oauth2ServerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Oauth2Server.PubSub,
  live_view: [signing_salt: "oauth2_tp_salt"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Joken JWT signer
config :joken, default_signer: [
  signer_alg: "HS256",
  key_octet: System.get_env("SECRET_KEY") || "super-secret-key-for-jwt-change-in-production-min-64-chars"
]

# Import environment specific config
import_config "#{config_env()}.exs"
