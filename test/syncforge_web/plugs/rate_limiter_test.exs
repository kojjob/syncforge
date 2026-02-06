defmodule SyncforgeWeb.Plugs.RateLimiterTest do
  use SyncforgeWeb.ConnCase, async: false

  alias SyncforgeWeb.Plugs.RateLimiter

  # Use the global Syncforge.RateLimiter (started in application supervisor).
  # Isolation is achieved via unique request paths per test.

  describe "rate_limit_request/3" do
    test "allows requests under the limit" do
      path = "/test-rl-#{System.unique_integer([:positive])}"
      conn = build_conn(:get, path) |> Map.put(:remote_ip, {127, 0, 0, 1})

      result =
        RateLimiter.rate_limit_request(conn, Syncforge.RateLimiter,
          limit: 10,
          scale: 60_000,
          by: :ip
        )

      assert result == :ok
    end

    test "denies requests over the limit" do
      path = "/test-rl-#{System.unique_integer([:positive])}"
      conn = build_conn(:get, path) |> Map.put(:remote_ip, {10, 0, 0, 1})

      # Exhaust the limit
      for _ <- 1..5 do
        :ok =
          RateLimiter.rate_limit_request(conn, Syncforge.RateLimiter,
            limit: 5,
            scale: 60_000,
            by: :ip
          )
      end

      # Next request should be denied
      result =
        RateLimiter.rate_limit_request(conn, Syncforge.RateLimiter,
          limit: 5,
          scale: 60_000,
          by: :ip
        )

      assert {:deny, retry_after} = result
      assert is_integer(retry_after)
      assert retry_after > 0
    end

    test "tracks different IPs independently" do
      path = "/test-rl-#{System.unique_integer([:positive])}"
      conn1 = build_conn(:get, path) |> Map.put(:remote_ip, {10, 0, 0, 1})
      conn2 = build_conn(:get, path) |> Map.put(:remote_ip, {10, 0, 0, 2})

      # Exhaust limit for conn1
      for _ <- 1..3 do
        :ok =
          RateLimiter.rate_limit_request(conn1, Syncforge.RateLimiter,
            limit: 3,
            scale: 60_000,
            by: :ip
          )
      end

      # conn1 should be denied
      assert {:deny, _} =
               RateLimiter.rate_limit_request(conn1, Syncforge.RateLimiter,
                 limit: 3,
                 scale: 60_000,
                 by: :ip
               )

      # conn2 should still be allowed
      assert :ok =
               RateLimiter.rate_limit_request(conn2, Syncforge.RateLimiter,
                 limit: 3,
                 scale: 60_000,
                 by: :ip
               )
    end
  end

  describe "plug integration" do
    test "returns 429 with Retry-After header when rate limited" do
      path = "/test-rl-#{System.unique_integer([:positive])}"
      opts = RateLimiter.init(limit: 2, scale: 60_000, by: :ip)

      # Use up the limit
      conn1 =
        build_conn(:post, path)
        |> Map.put(:remote_ip, {192, 168, 1, 1})
        |> RateLimiter.call(opts)

      refute conn1.halted

      conn2 =
        build_conn(:post, path)
        |> Map.put(:remote_ip, {192, 168, 1, 1})
        |> RateLimiter.call(opts)

      refute conn2.halted

      # Third should be rate limited
      conn3 =
        build_conn(:post, path)
        |> Map.put(:remote_ip, {192, 168, 1, 1})
        |> RateLimiter.call(opts)

      assert conn3.halted
      assert conn3.status == 429

      body = Jason.decode!(conn3.resp_body)
      assert body["error"] =~ "Rate limit exceeded"

      retry_after = Plug.Conn.get_resp_header(conn3, "retry-after") |> List.first()
      assert retry_after != nil
    end

    test "passes through when rate limiting is disabled" do
      conn = build_conn(:get, "/api/me")
      opts = RateLimiter.init(disabled: true)

      result = RateLimiter.call(conn, opts)
      refute result.halted
    end
  end
end
