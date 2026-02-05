import Config

# Configure your database (MySQL for tests)
config :oauth2_server, Oauth2Server.Repo,
  hostname: System.get_env("DB_HOST") || "localhost",
  port: String.to_integer(System.get_env("DB_PORT") || "3306"),
  username: System.get_env("DB_USER") || "root",
  password: System.get_env("DB_PASSWORD") || "12345678",
  database: "oauth2_server_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test
config :oauth2_server, Oauth2ServerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_at_least_64_chars_long_for_security_purposes",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
