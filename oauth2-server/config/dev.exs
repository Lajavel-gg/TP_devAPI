import Config

# Configure your database (MySQL)
config :oauth2_server, Oauth2Server.Repo,
  hostname: System.get_env("MYSQL_HOST") || "localhost",
  port: String.to_integer(System.get_env("MYSQL_PORT") || "3306"),
  username: System.get_env("MYSQL_USER") || "sirenuser",
  password: System.get_env("MYSQL_PASSWORD") || "12345678",
  database: System.get_env("MYSQL_DATABASE") || "siren",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable debugging
config :oauth2_server, Oauth2ServerWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: false,
  debug_errors: true,
  secret_key_base: System.get_env("SECRET_KEY_BASE") || "dev_secret_key_base_at_least_64_characters_long_for_security_purposes",
  watchers: []

# Enable dev routes for dashboard
config :oauth2_server, dev_routes: true

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
