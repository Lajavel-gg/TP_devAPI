defmodule Oauth2ServerWeb.Router do
  use Oauth2ServerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug CORSPlug, origin: "*"
  end

  # Health check
  scope "/", Oauth2ServerWeb do
    pipe_through :api
    get "/health", HealthController, :index
  end

  # OAuth2 API endpoints
  scope "/oauth", Oauth2ServerWeb do
    pipe_through :api

    post "/token", TokenController, :token
    post "/introspect", IntrospectController, :introspect
  end

  # Swagger UI
  scope "/swagger" do
    pipe_through :browser
    get "/", Oauth2ServerWeb.SwaggerController, :index
  end

  # API docs
  scope "/api-docs" do
    pipe_through :browser
    get "/", Oauth2ServerWeb.SwaggerController, :index
  end
end
