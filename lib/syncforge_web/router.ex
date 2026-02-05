defmodule SyncforgeWeb.Router do
  use SyncforgeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SyncforgeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SyncforgeWeb do
    pipe_through :browser

    # Landing page (LiveView)
    live "/", LandingLive, :index

    # Keep home page at /home if needed
    get "/home", PageController, :home
  end

  # Public auth endpoints (no authentication required)
  scope "/api", SyncforgeWeb do
    pipe_through :api

    post "/register", AuthController, :register
    post "/login", AuthController, :login
  end

  # Protected API endpoints (Bearer token required)
  scope "/api", SyncforgeWeb do
    pipe_through [:api, SyncforgeWeb.Plugs.RequireAuth]

    get "/me", AuthController, :me
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:syncforge, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
