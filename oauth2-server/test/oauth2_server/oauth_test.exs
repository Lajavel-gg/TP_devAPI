defmodule Oauth2Server.OAuthTest do
  use ExUnit.Case, async: true

  alias Oauth2Server.OAuth

  describe "authenticate_client/2" do
    test "returns ok with valid client credentials" do
      assert {:ok, client} = OAuth.authenticate_client("mysql-api-client", "mysql_api_secret")
      assert client.id == "mysql-api-client"
      assert client.name == "MySQL API Client"
    end

    test "returns ok for spark-api-client" do
      assert {:ok, client} = OAuth.authenticate_client("spark-api-client", "spark_api_secret")
      assert client.id == "spark-api-client"
    end

    test "returns ok for frontend-client" do
      assert {:ok, client} = OAuth.authenticate_client("frontend-client", "frontend_secret")
      assert client.id == "frontend-client"
    end

    test "returns error for unknown client" do
      assert {:error, "Client not found"} = OAuth.authenticate_client("unknown-client", "secret")
    end

    test "returns error for invalid secret" do
      assert {:error, "Invalid client secret"} = OAuth.authenticate_client("mysql-api-client", "wrong_secret")
    end
  end

  describe "generate_token/2" do
    test "generates a valid JWT token" do
      {:ok, client} = OAuth.authenticate_client("mysql-api-client", "mysql_api_secret")
      assert {:ok, token, ttl} = OAuth.generate_token(client, "read")

      assert is_binary(token)
      assert ttl == 3600
      # JWT format: header.payload.signature
      assert length(String.split(token, ".")) == 3
    end

    test "generates token with custom scope" do
      {:ok, client} = OAuth.authenticate_client("mysql-api-client", "mysql_api_secret")
      assert {:ok, token, _ttl} = OAuth.generate_token(client, "read write")

      # Verify the token contains the scope
      {:ok, token_info} = OAuth.introspect_token(token)
      assert token_info.scope == "read write"
    end
  end

  describe "introspect_token/1" do
    test "returns token info for valid token" do
      {:ok, client} = OAuth.authenticate_client("mysql-api-client", "mysql_api_secret")
      {:ok, token, _ttl} = OAuth.generate_token(client, "read")

      assert {:ok, token_info} = OAuth.introspect_token(token)
      assert token_info.client_id == "mysql-api-client"
      assert token_info.scope == "read"
      assert token_info.exp > System.system_time(:second)
    end

    test "returns error for invalid token" do
      assert {:error, "Invalid token"} = OAuth.introspect_token("invalid.token.here")
    end

    test "returns error for nil token" do
      assert {:error, "Token required"} = OAuth.introspect_token(nil)
    end

    test "returns error for empty string token" do
      assert {:error, "Invalid token"} = OAuth.introspect_token("")
    end

    test "returns error for expired token" do
      # Create a token that's already expired by manipulating claims directly
      secret = "super-secret-key-for-jwt-change-in-production-min-64-chars"
      signer = Joken.Signer.create("HS256", secret)

      expired_claims = %{
        "sub" => "test-client",
        "client_id" => "test-client",
        "scope" => "read",
        "iat" => System.system_time(:second) - 7200,
        "exp" => System.system_time(:second) - 3600,
        "type" => "access_token"
      }

      {:ok, expired_token, _} = Joken.generate_and_sign(%{}, expired_claims, signer)

      assert {:error, "Token expired"} = OAuth.introspect_token(expired_token)
    end
  end
end
