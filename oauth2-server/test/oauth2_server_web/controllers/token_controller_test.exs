defmodule Oauth2ServerWeb.TokenControllerTest do
  use Oauth2ServerWeb.ConnCase, async: true

  describe "POST /oauth/token" do
    test "returns token for valid client_credentials grant", %{conn: conn} do
      conn = post(conn, "/oauth/token", %{
        "grant_type" => "client_credentials",
        "client_id" => "mysql-api-client",
        "client_secret" => "mysql_api_secret",
        "scope" => "read"
      })

      response = json_response(conn, 200)
      assert response["access_token"]
      assert response["token_type"] == "Bearer"
      assert response["expires_in"] == 3600
      assert response["scope"] == "read"
    end

    test "returns token using Basic Auth", %{conn: conn} do
      credentials = Base.encode64("mysql-api-client:mysql_api_secret")

      conn = conn
      |> put_req_header("authorization", "Basic #{credentials}")
      |> post("/oauth/token", %{
        "grant_type" => "client_credentials",
        "scope" => "read"
      })

      response = json_response(conn, 200)
      assert response["access_token"]
      assert response["token_type"] == "Bearer"
    end

    test "returns error for invalid client", %{conn: conn} do
      conn = post(conn, "/oauth/token", %{
        "grant_type" => "client_credentials",
        "client_id" => "unknown-client",
        "client_secret" => "secret"
      })

      response = json_response(conn, 401)
      assert response["error"] == "invalid_client"
    end

    test "returns error for invalid client secret", %{conn: conn} do
      conn = post(conn, "/oauth/token", %{
        "grant_type" => "client_credentials",
        "client_id" => "mysql-api-client",
        "client_secret" => "wrong_secret"
      })

      response = json_response(conn, 401)
      assert response["error"] == "invalid_client"
    end

    test "returns error for unsupported grant type", %{conn: conn} do
      conn = post(conn, "/oauth/token", %{
        "grant_type" => "password",
        "client_id" => "mysql-api-client",
        "client_secret" => "mysql_api_secret"
      })

      response = json_response(conn, 400)
      assert response["error"] == "unsupported_grant_type"
    end

    test "uses default scope when not provided", %{conn: conn} do
      conn = post(conn, "/oauth/token", %{
        "grant_type" => "client_credentials",
        "client_id" => "mysql-api-client",
        "client_secret" => "mysql_api_secret"
      })

      response = json_response(conn, 200)
      assert response["scope"] == "read"
    end
  end
end
