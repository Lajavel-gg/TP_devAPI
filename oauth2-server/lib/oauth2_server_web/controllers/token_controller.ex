defmodule Oauth2ServerWeb.TokenController do
  @moduledoc """
  Controller for OAuth2 token endpoint.
  Supports client_credentials grant type.
  """
  use Oauth2ServerWeb, :controller

  alias Oauth2Server.OAuth

  def token(conn, params) do
    grant_type = params["grant_type"]

    # Get client credentials from params or Basic Auth header
    {client_id, client_secret} = get_client_credentials(conn, params)

    case grant_type do
      "client_credentials" ->
        handle_client_credentials(conn, client_id, client_secret, params["scope"])

      _ ->
        conn
        |> put_status(400)
        |> json(%{error: "unsupported_grant_type", error_description: "Grant type not supported"})
    end
  end

  defp get_client_credentials(conn, params) do
    # Try Basic Auth first
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded] ->
        case Base.decode64(encoded) do
          {:ok, decoded} ->
            case String.split(decoded, ":", parts: 2) do
              [id, secret] -> {id, secret}
              _ -> {params["client_id"], params["client_secret"]}
            end
          _ -> {params["client_id"], params["client_secret"]}
        end
      _ -> {params["client_id"], params["client_secret"]}
    end
  end

  defp handle_client_credentials(conn, client_id, client_secret, scope) do
    case OAuth.authenticate_client(client_id, client_secret) do
      {:ok, client} ->
        scope = scope || "read"
        {:ok, token, expires_in} = OAuth.generate_token(client, scope)

        conn
        |> put_resp_header("cache-control", "no-store")
        |> put_resp_header("pragma", "no-cache")
        |> json(%{
          access_token: token,
          token_type: "Bearer",
          expires_in: expires_in,
          scope: scope
        })

      {:error, reason} ->
        conn
        |> put_status(401)
        |> json(%{error: "invalid_client", error_description: reason})
    end
  end
end
