defmodule Oauth2ServerWeb.IntrospectControllerTest do
  use Oauth2ServerWeb.ConnCase, async: true

  alias Oauth2Server.OAuth

  setup do
    # Generate a valid token for tests
    {:ok, client} = OAuth.authenticate_client("mysql-api-client", "mysql_api_secret")
    {:ok, token, _ttl} = OAuth.generate_token(client, "read")

    {:ok, token: token}
  end

  describe "POST /oauth/introspect" do
    test "returns active true for valid token", %{conn: conn, token: token} do
      credentials = Base.encode64("mysql-api-client:mysql_api_secret")

      conn = conn
      |> put_req_header("authorization", "Basic #{credentials}")
      |> post("/oauth/introspect", %{"token" => token})

      response = json_response(conn, 200)
      assert response["active"] == true
      assert response["client_id"] == "mysql-api-client"
      assert response["scope"] == "read"
      assert response["token_type"] == "Bearer"
    end

    test "returns active false for invalid token", %{conn: conn} do
      credentials = Base.encode64("mysql-api-client:mysql_api_secret")

      conn = conn
      |> put_req_header("authorization", "Basic #{credentials}")
      |> post("/oauth/introspect", %{"token" => "invalid.token.here"})

      response = json_response(conn, 200)
      assert response["active"] == false
    end

    test "returns error without Basic Auth", %{conn: conn, token: token} do
      conn = post(conn, "/oauth/introspect", %{"token" => token})

      response = json_response(conn, 401)
      assert response["error"] == "invalid_client"
      assert response["error_description"] == "Basic authentication required"
    end

    test "returns error for invalid client credentials", %{conn: conn, token: token} do
      credentials = Base.encode64("mysql-api-client:wrong_secret")

      conn = conn
      |> put_req_header("authorization", "Basic #{credentials}")
      |> post("/oauth/introspect", %{"token" => token})

      response = json_response(conn, 401)
      assert response["error"] == "invalid_client"
    end

    test "different client can introspect token", %{conn: conn, token: token} do
      # spark-api-client introspects a token issued to mysql-api-client
      credentials = Base.encode64("spark-api-client:spark_api_secret")

      conn = conn
      |> put_req_header("authorization", "Basic #{credentials}")
      |> post("/oauth/introspect", %{"token" => token})

      response = json_response(conn, 200)
      assert response["active"] == true
      assert response["client_id"] == "mysql-api-client"
    end
  end
end
