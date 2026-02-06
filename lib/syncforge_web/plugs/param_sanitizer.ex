defmodule SyncforgeWeb.Plugs.ParamSanitizer do
  @moduledoc """
  Sanitizes request parameters to prevent abuse.

  - Strips leading/trailing whitespace from strings
  - Rejects null bytes in string values
  - Rejects strings exceeding 10,000 characters
  - Rejects deeply nested JSON (max depth 10)
  """

  import Plug.Conn

  @behaviour Plug

  @max_string_length 10_000
  @max_depth 10

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case sanitize_params(conn.params) do
      {:ok, sanitized} ->
        %{conn | params: sanitized}

      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: message}))
        |> halt()
    end
  end

  defp sanitize_params(params) do
    sanitize_value(params, 0)
  end

  defp sanitize_value(value, depth) when is_map(value) do
    if depth >= @max_depth do
      {:error, "Request contains too deeply nested data (max depth #{@max_depth})"}
    else
      value
      |> Enum.reduce_while({:ok, %{}}, fn {key, val}, {:ok, acc} ->
        case sanitize_value(val, depth + 1) do
          {:ok, sanitized} -> {:cont, {:ok, Map.put(acc, key, sanitized)}}
          {:error, _} = err -> {:halt, err}
        end
      end)
    end
  end

  defp sanitize_value(value, depth) when is_list(value) do
    if depth >= @max_depth do
      {:error, "Request contains too deeply nested data (max depth #{@max_depth})"}
    else
      value
      |> Enum.reduce_while({:ok, []}, fn val, {:ok, acc} ->
        case sanitize_value(val, depth + 1) do
          {:ok, sanitized} -> {:cont, {:ok, [sanitized | acc]}}
          {:error, _} = err -> {:halt, err}
        end
      end)
      |> case do
        {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
        error -> error
      end
    end
  end

  defp sanitize_value(value, _depth) when is_binary(value) do
    cond do
      String.contains?(value, "\0") ->
        {:error, "Request contains null bytes in parameter values"}

      String.length(value) > @max_string_length ->
        {:error, "Parameter value exceeds maximum length of #{@max_string_length} characters"}

      true ->
        {:ok, String.trim(value)}
    end
  end

  defp sanitize_value(value, _depth), do: {:ok, value}
end
