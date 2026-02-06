defmodule Syncforge.RateLimiter do
  @moduledoc """
  ETS-backed rate limiter for HTTP and WebSocket rate limiting.

  Uses Hammer 7's ETS backend. Start this in the application supervisor.
  """

  use Hammer, backend: :ets
end
