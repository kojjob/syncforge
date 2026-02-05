defmodule Syncforge.Repo do
  use Ecto.Repo,
    otp_app: :syncforge,
    adapter: Ecto.Adapters.Postgres
end
