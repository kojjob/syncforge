defmodule SyncforgeWeb.Router do
  use SyncforgeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SyncforgeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug SyncforgeWeb.Plugs.SecurityHeaders, mode: :browser
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug SyncforgeWeb.Plugs.SecurityHeaders, mode: :api
    plug SyncforgeWeb.Plugs.ParamSanitizer
  end

  # Rate limiting pipelines
  pipeline :rate_limit_public_auth do
    plug SyncforgeWeb.Plugs.RateLimiter,
      limit: 10,
      scale: 60_000,
      by: :ip
  end

  pipeline :rate_limit_webhook do
    plug SyncforgeWeb.Plugs.RateLimiter,
      limit: 100,
      scale: 60_000,
      by: :ip
  end

  pipeline :rate_limit_protected do
    plug SyncforgeWeb.Plugs.RateLimiter,
      limit: 300,
      scale: 60_000,
      by: :user
  end

  scope "/", SyncforgeWeb do
    pipe_through :browser

    # Landing page (LiveView)
    live "/", LandingLive, :index

    # Keep home page at /home if needed
    get "/home", PageController, :home
  end

  # Browser session management (POST to set cookie, DELETE to clear)
  scope "/", SyncforgeWeb do
    pipe_through :browser

    post "/session", UserSessionController, :create
    delete "/session", UserSessionController, :delete
  end

  # Unauthenticated LiveView pages (login/register)
  # Redirects away if user is already logged in
  scope "/", SyncforgeWeb do
    pipe_through :browser

    live_session :unauthenticated,
      on_mount: [{SyncforgeWeb.Live.Hooks.RedirectIfAuthenticated, :redirect_if_authenticated}] do
      live "/login", UserLoginLive
      live "/register", UserRegisterLive
    end
  end

  # Authenticated LiveView pages (dashboard)
  # Requires user to be logged in via session cookie
  scope "/", SyncforgeWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: [{SyncforgeWeb.Live.Hooks.RequireLiveAuth, :require_auth}],
      layout: {SyncforgeWeb.Layouts, :dashboard} do
      live "/dashboard", DashboardLive
      live "/dashboard/rooms", RoomsLive
      live "/dashboard/api-keys", ApiKeysLive
      live "/dashboard/analytics", AnalyticsLive
      live "/dashboard/logs", LogsLive
      live "/dashboard/billing", BillingLive
    end
  end

  # Health check (no auth — used by load balancers and orchestrators)
  scope "/", SyncforgeWeb do
    pipe_through :api

    get "/health", HealthController, :show
  end

  # Stripe webhook (no auth — verified by Stripe signature)
  scope "/api/webhooks", SyncforgeWeb do
    pipe_through [:api, :rate_limit_webhook]

    post "/stripe", StripeWebhookController, :handle
  end

  # Public auth endpoints (no authentication required)
  scope "/api", SyncforgeWeb do
    pipe_through [:api, :rate_limit_public_auth]

    post "/register", AuthController, :register
    post "/login", AuthController, :login
    post "/forgot-password", AuthController, :forgot_password
    post "/reset-password", AuthController, :reset_password
    post "/confirm-email", AuthController, :confirm_email
  end

  # Protected API endpoints (Bearer token required)
  scope "/api", SyncforgeWeb do
    pipe_through [:api, SyncforgeWeb.Plugs.RequireAuth, :rate_limit_protected]

    get "/me", AuthController, :me
    post "/resend-confirmation", AuthController, :resend_confirmation

    # Organization CRUD
    resources "/organizations", OrganizationController,
      only: [:create, :index, :show, :update, :delete] do
      # Membership management
      post "/members", OrganizationController, :add_member
      delete "/members/:user_id", OrganizationController, :remove_member
      put "/members/:user_id/role", OrganizationController, :update_member_role

      # API key management
      post "/api-keys", OrganizationController, :create_api_key
      get "/api-keys", OrganizationController, :list_api_keys
      delete "/api-keys/:id", OrganizationController, :revoke_api_key
      post "/api-keys/:id/rotate", OrganizationController, :rotate_api_key
    end

    # Billing management (scoped to org, requires owner/admin)
    scope "/organizations/:org_id/billing", as: :billing do
      post "/checkout", BillingController, :create_checkout_session
      post "/portal", BillingController, :create_portal_session
      get "/subscription", BillingController, :show_subscription
    end
  end

  # Enable Swoosh mailbox preview in development
  if Application.compile_env(:syncforge, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
