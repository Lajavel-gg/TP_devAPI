defmodule Oauth2Server.OAuth do
  @moduledoc """
  OAuth2 business logic module.
  Handles client authentication, token generation and introspection.
  """

  alias Oauth2Server.Repo
  import Ecto.Query

  @token_ttl 3600

  # Clients preconfigures (stockes en memoire pour simplicite)
  # En production, utiliser la base de donnees
  @clients %{
    "mysql-api-client" => %{
      id: "mysql-api-client",
      secret: "mysql_api_secret",
      name: "MySQL API Client"
    },
    "spark-api-client" => %{
      id: "spark-api-client",
      secret: "spark_api_secret",
      name: "Spark API Client"
    },
    "frontend-client" => %{
      id: "frontend-client",
      secret: "frontend_secret",
      name: "Frontend Client"
    }
  }

  @doc """
  Authenticate a client by ID and secret.
  """
  def authenticate_client(client_id, client_secret) do
    case Map.get(@clients, client_id) do
      nil ->
        {:error, "Client not found"}

      client ->
        if client.secret == client_secret do
          {:ok, client}
        else
          {:error, "Invalid client secret"}
        end
    end
  end

  @doc """
  Generate a JWT token for a client.
  """
  def generate_token(client, scope) do
    now = System.system_time(:second)
    exp = now + @token_ttl

    claims = %{
      "sub" => client.id,
      "client_id" => client.id,
      "scope" => scope,
      "iat" => now,
      "exp" => exp,
      "type" => "access_token"
    }

    secret = get_secret_key()
    signer = Joken.Signer.create("HS256", secret)

    case Joken.generate_and_sign(%{}, claims, signer) do
      {:ok, token, _claims} ->
        # Store token in database
        store_token(token, client.id, scope, exp)
        {:ok, token, @token_ttl}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Introspect a token to check if it's valid.
  """
  def introspect_token(token) when is_binary(token) do
    secret = get_secret_key()
    signer = Joken.Signer.create("HS256", secret)

    case Joken.verify_and_validate(%{}, token, signer) do
      {:ok, claims} ->
        now = System.system_time(:second)
        exp = claims["exp"] || 0

        if exp > now do
          {:ok, %{
            client_id: claims["client_id"] || claims["sub"],
            scope: claims["scope"] || "read",
            exp: exp,
            iat: claims["iat"]
          }}
        else
          {:error, "Token expired"}
        end

      {:error, _reason} ->
        {:error, "Invalid token"}
    end
  end

  def introspect_token(_), do: {:error, "Token required"}

  defp get_secret_key do
    Application.get_env(:oauth2_server, :jwt)[:secret_key] ||
      "super-secret-key-for-jwt-change-in-production-min-64-chars"
  end

  defp store_token(token, client_id, scope, expires_at) do
    # Store in oauth_tokens table if exists
    try do
      expires_at_dt = DateTime.from_unix!(expires_at)

      Repo.query(
        "INSERT INTO oauth_tokens (token, client_id, scopes, expires_at, created_at) VALUES (?, ?, ?, ?, NOW())",
        [token, client_id, scope, expires_at_dt]
      )
    rescue
      _ -> :ok  # Table might not exist, ignore
    end
  end
end
