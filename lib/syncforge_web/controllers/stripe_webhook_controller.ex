defmodule SyncforgeWeb.StripeWebhookController do
  use SyncforgeWeb, :controller

  require Logger

  @compile {:no_warn_undefined, [Stripe.Webhook]}

  alias Syncforge.Billing

  @doc """
  Handles incoming Stripe webhook events.

  In production, verifies the webhook signature using the raw body
  and the Stripe-Signature header. In test, processes events directly.
  """
  def handle(conn, _params) do
    case verify_and_parse_event(conn) do
      {:ok, event} ->
        case Billing.process_webhook_event(event) do
          :ok ->
            json(conn, %{status: "ok"})

          {:error, reason} ->
            Logger.error("Webhook processing failed: #{inspect(reason)}")
            conn |> put_status(:unprocessable_entity) |> json(%{error: "Processing failed"})
        end

      {:error, reason} ->
        Logger.warning("Webhook verification failed: #{inspect(reason)}")
        conn |> put_status(:bad_request) |> json(%{error: "Invalid webhook"})
    end
  end

  defp verify_and_parse_event(conn) do
    raw_body = conn.private[:raw_body] || ""
    signature = Plug.Conn.get_req_header(conn, "stripe-signature") |> List.first()
    webhook_secret = Application.get_env(:syncforge, :stripe_webhook_secret)

    cond do
      is_nil(webhook_secret) or webhook_secret == "" ->
        # No secret configured — accept events without verification (dev/test only)
        {:ok, atomize_event(conn.body_params)}

      is_nil(signature) ->
        {:error, :missing_signature}

      true ->
        case Stripe.Webhook.construct_event(raw_body, signature, webhook_secret) do
          {:ok, event} -> {:ok, event}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  # Convert string-keyed body_params to the atom-keyed map our Billing context expects
  defp atomize_event(params) when is_map(params) do
    Map.new(params, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), atomize_event(v)}
      {k, v} -> {k, atomize_event(v)}
    end)
  end

  defp atomize_event(list) when is_list(list), do: Enum.map(list, &atomize_event/1)
  defp atomize_event(other), do: other
end
