defmodule Oauth2ServerWeb.SwaggerController do
  use Oauth2ServerWeb, :controller

  @openapi_spec """
  {
    "openapi": "3.0.0",
    "info": {
      "title": "OAuth2 Server API",
      "version": "1.0.0",
      "description": "Serveur OAuth2 Elixir/Phoenix - Supporte client_credentials et introspection"
    },
    "servers": [{"url": "http://localhost:4000"}],
    "paths": {
      "/oauth/token": {
        "post": {
          "summary": "Obtenir un token",
          "tags": ["OAuth2"],
          "requestBody": {
            "content": {
              "application/x-www-form-urlencoded": {
                "schema": {
                  "type": "object",
                  "required": ["grant_type", "client_id", "client_secret"],
                  "properties": {
                    "grant_type": {"type": "string", "enum": ["client_credentials"]},
                    "client_id": {"type": "string"},
                    "client_secret": {"type": "string"},
                    "scope": {"type": "string", "default": "read"}
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Token genere",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "access_token": {"type": "string"},
                      "token_type": {"type": "string"},
                      "expires_in": {"type": "integer"},
                      "scope": {"type": "string"}
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/oauth/introspect": {
        "post": {
          "summary": "Introspecter un token",
          "tags": ["OAuth2"],
          "security": [{"basicAuth": []}],
          "requestBody": {
            "content": {
              "application/x-www-form-urlencoded": {
                "schema": {
                  "type": "object",
                  "required": ["token"],
                  "properties": {
                    "token": {"type": "string"}
                  }
                }
              }
            }
          },
          "responses": {
            "200": {
              "description": "Info token",
              "content": {
                "application/json": {
                  "schema": {
                    "type": "object",
                    "properties": {
                      "active": {"type": "boolean"},
                      "client_id": {"type": "string"},
                      "scope": {"type": "string"},
                      "exp": {"type": "integer"}
                    }
                  }
                }
              }
            }
          }
        }
      },
      "/health": {
        "get": {
          "summary": "Health check",
          "tags": ["System"],
          "responses": {
            "200": {"description": "OK"}
          }
        }
      }
    },
    "components": {
      "securitySchemes": {
        "basicAuth": {
          "type": "http",
          "scheme": "basic"
        }
      }
    }
  }
  """

  def index(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>OAuth2 Server - Elixir/Phoenix</title>
      <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
      <script>
        SwaggerUIBundle({
          spec: #{@openapi_spec},
          dom_id: '#swagger-ui',
          presets: [SwaggerUIBundle.presets.apis, SwaggerUIBundle.SwaggerUIStandalonePreset],
          layout: "BaseLayout"
        });
      </script>
    </body>
    </html>
    """)
  end
end
