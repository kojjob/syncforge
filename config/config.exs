# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :syncforge,
  ecto_repos: [Syncforge.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :syncforge, SyncforgeWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SyncforgeWeb.ErrorHTML, json: SyncforgeWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Syncforge.PubSub,
  live_view: [signing_salt: "OKhwMsC2"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :syncforge, Syncforge.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  syncforge: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  syncforge: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :room_id]

# Sentry error tracking (DSN set in runtime.exs for prod only)
config :sentry,
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Stripe billing configuration
config :stripity_stripe, api_key: System.get_env("STRIPE_SECRET_KEY")

config :syncforge, :stripe_client, Syncforge.Billing.StripeClient.Live

config :syncforge, :stripe_prices, %{
  starter: System.get_env("STRIPE_PRICE_STARTER") || "price_starter",
  pro: System.get_env("STRIPE_PRICE_PRO") || "price_pro",
  business: System.get_env("STRIPE_PRICE_BUSINESS") || "price_business"
}

config :syncforge, :stripe_webhook_secret, System.get_env("STRIPE_WEBHOOK_SECRET")

# CORS allowed origins (overridden per environment)
config :syncforge, :cors_allowed_origins, :all

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
