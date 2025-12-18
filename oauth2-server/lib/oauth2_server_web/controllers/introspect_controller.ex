defmodule Oauth2ServerWeb.IntrospectController do
  @moduledoc """
  Controller for OAuth2 token introspection endpoint.
  Used by resource servers to validate tokens.
  """
  use Oauth2ServerWeb, :controller

  alias Oauth2Server.OAuth

  def introspect(conn, params) do
    token = params["token"]

    # Verify client credentials (Basic Auth required for introspection)
    case get_client_from_auth(conn) do
      {:ok, _client_id} ->
        case OAuth.introspect_token(token) do
          {:ok, token_info} ->
            conn
            |> json(%{
              active: true,
              client_id: token_info.client_id,
              scope: token_info.scope,
              exp: token_info.exp,
              iat: token_info.iat,
              token_type: "Bearer"
            })

          {:error, _reason} ->
            conn
            |> json(%{active: false})
        end

      {:error, reason} ->
        conn
        |> put_status(401)
        |> json(%{error: "invalid_client", error_description: reason})
    end
  end

  defp get_client_from_auth(conn) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded] ->
        case Base.decode64(encoded) do
          {:ok, decoded} ->
            case String.split(decoded, ":", parts: 2) do
              [client_id, client_secret] ->
                case OAuth.authenticate_client(client_id, client_secret) do
                  {:ok, _client} -> {:ok, client_id}
                  error -> error
                end
              _ -> {:error, "Invalid authorization header format"}
            end
          _ -> {:error, "Invalid base64 encoding"}
        end
      _ -> {:error, "Basic authentication required"}
    end
  end
end
