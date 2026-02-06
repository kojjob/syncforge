defmodule SyncforgeWeb.Plugs.ParamSanitizerTest do
  use SyncforgeWeb.ConnCase, async: true

  alias SyncforgeWeb.Plugs.ParamSanitizer

  describe "call/2" do
    test "strips leading/trailing whitespace from string params" do
      conn =
        build_conn(:get, "/", %{"name" => "  hello  ", "email" => " test@example.com "})
        |> ParamSanitizer.call([])

      assert conn.params["name"] == "hello"
      assert conn.params["email"] == "test@example.com"
    end

    test "rejects null bytes in string params" do
      conn =
        build_conn(:get, "/", %{"name" => "hello\0world"})
        |> ParamSanitizer.call([])

      assert conn.halted
      assert conn.status == 400

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "null bytes"
    end

    test "rejects strings exceeding max length" do
      long_string = String.duplicate("a", 10_001)

      conn =
        build_conn(:get, "/", %{"name" => long_string})
        |> ParamSanitizer.call([])

      assert conn.halted
      assert conn.status == 400

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "exceeds maximum"
    end

    test "allows strings at exactly max length" do
      max_string = String.duplicate("a", 10_000)

      conn =
        build_conn(:get, "/", %{"name" => max_string})
        |> ParamSanitizer.call([])

      refute conn.halted
      assert conn.params["name"] == max_string
    end

    test "rejects deeply nested JSON (depth > 10)" do
      deep_params = build_nested_map(11)

      conn =
        build_conn(:post, "/", deep_params)
        |> ParamSanitizer.call([])

      assert conn.halted
      assert conn.status == 400

      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "deeply nested"
    end

    test "allows nesting up to depth 10" do
      params = build_nested_map(10)

      conn =
        build_conn(:post, "/", params)
        |> ParamSanitizer.call([])

      refute conn.halted
    end

    test "strips whitespace in nested map values" do
      conn =
        build_conn(:post, "/", %{"user" => %{"name" => "  Alice  ", "age" => "30"}})
        |> ParamSanitizer.call([])

      refute conn.halted
      assert conn.params["user"]["name"] == "Alice"
    end

    test "strips whitespace in list values" do
      conn =
        build_conn(:post, "/", %{"tags" => ["  elixir  ", " phoenix "]})
        |> ParamSanitizer.call([])

      refute conn.halted
      assert conn.params["tags"] == ["elixir", "phoenix"]
    end

    test "passes through non-string values unchanged" do
      conn =
        build_conn(:post, "/", %{"count" => 42, "active" => true})
        |> ParamSanitizer.call([])

      refute conn.halted
      assert conn.params["count"] == 42
      assert conn.params["active"] == true
    end

    test "handles empty params" do
      conn =
        build_conn(:get, "/", %{})
        |> ParamSanitizer.call([])

      refute conn.halted
    end
  end

  # Builds a nested map of specified depth: %{"a" => %{"a" => %{...}}}
  defp build_nested_map(1), do: %{"a" => "leaf"}

  defp build_nested_map(depth) when depth > 1 do
    %{"a" => build_nested_map(depth - 1)}
  end
end
