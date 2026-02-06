import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :syncforge, Syncforge.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "syncforge_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :syncforge, SyncforgeWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "997aEWSg5dLdx4tgC/+hYAgg+BCjP/k6B1Fsnrtbumpc4mFDMkOvOpMyYKFipsD4",
  server: false

# In test we don't send emails
config :syncforge, Syncforge.Mailer, adapter: Swoosh.Adapters.Test

# Mark test environment for runtime checks
config :syncforge, :env, :test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Faster bcrypt hashing in tests
config :bcrypt_elixir, log_rounds: 4

# Stripe test configuration
config :stripity_stripe, api_key: "sk_test_fake_key_for_tests"
config :syncforge, :stripe_client, Syncforge.Billing.StripeClientMock
config :syncforge, :stripe_webhook_secret, "whsec_test_secret"

config :syncforge, :stripe_prices, %{
  starter: "price_test_starter",
  pro: "price_test_pro",
  business: "price_test_business"
}

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
