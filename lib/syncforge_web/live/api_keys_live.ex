defmodule SyncforgeWeb.ApiKeysLive do
  @moduledoc """
  API Key management page: list, create, and revoke API keys
  for the current organization.
  """

  use SyncforgeWeb, :live_view

  alias Syncforge.Organizations

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    organizations = Organizations.list_user_organizations(user.id)
    current_org = pick_org(organizations, session["current_org_id"])

    api_keys = if current_org, do: load_keys(current_org.id, false), else: []

    {:ok,
     socket
     |> assign(
       page_title: "API Keys",
       organizations: organizations,
       current_org: current_org,
       active_nav: :api_keys,
       api_keys: api_keys,
       show_revoked: false,
       revealed_key: nil
     )}
  end

  @impl true
  def handle_event("create_key", %{"api_key" => params}, socket) do
    org = socket.assigns.current_org

    if org do
      case Organizations.create_api_key(org, %{
             label: params["label"],
             type: params["type"] || "publishable"
           }) do
        {:ok, _key, raw_key} ->
          api_keys = load_keys(org.id, socket.assigns.show_revoked)

          {:noreply,
           socket
           |> assign(api_keys: api_keys, revealed_key: raw_key)
           |> put_flash(:info, "API key created! Copy the key now — it won't be shown again.")}

        {:error, changeset} ->
          message =
            changeset
            |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
            |> Enum.map_join(", ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)

          {:noreply, put_flash(socket, :error, "Failed to create key: #{message}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("revoke_key", %{"id" => key_id}, socket) do
    org = socket.assigns.current_org

    if org do
      case Organizations.get_api_key_for_org(org.id, key_id) do
        nil ->
          {:noreply, put_flash(socket, :error, "Key not found")}

        key ->
          {:ok, _} = Organizations.revoke_api_key(key)
          api_keys = load_keys(org.id, socket.assigns.show_revoked)

          {:noreply,
           socket
           |> assign(api_keys: api_keys)
           |> put_flash(:info, "API key revoked")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_revoked", _params, socket) do
    show_revoked = !socket.assigns.show_revoked
    org = socket.assigns.current_org
    api_keys = if org, do: load_keys(org.id, show_revoked), else: []

    {:noreply, assign(socket, show_revoked: show_revoked, api_keys: api_keys)}
  end

  @impl true
  def handle_event("dismiss_key", _params, socket) do
    {:noreply, assign(socket, revealed_key: nil)}
  end

  @impl true
  def handle_event("switch_org", %{"org_id" => org_id}, socket) do
    org = Enum.find(socket.assigns.organizations, &(&1.id == org_id))

    if org do
      api_keys = load_keys(org.id, socket.assigns.show_revoked)
      {:noreply, assign(socket, current_org: org, api_keys: api_keys, revealed_key: nil)}
    else
      {:noreply, socket}
    end
  end

  defp pick_org([], _), do: nil

  defp pick_org(organizations, session_org_id) when is_binary(session_org_id) do
    Enum.find(organizations, List.first(organizations), &(&1.id == session_org_id))
  end

  defp pick_org(organizations, _), do: List.first(organizations)

  defp load_keys(org_id, show_revoked) do
    Organizations.list_api_keys(org_id, include_revoked: show_revoked)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-8">
        <h1 class="text-2xl font-bold">API Keys</h1>
        <p class="text-base-content/60 mt-1">
          Manage API keys for your organization.
        </p>
      </div>

      <%= if @current_org do %>
        <%!-- Revealed Key Banner --%>
        <%= if @revealed_key do %>
          <div class="alert alert-warning mb-6">
            <.icon name="hero-exclamation-triangle" class="size-5" />
            <div class="flex-1">
              <p class="font-medium">Copy your API key now!</p>
              <p class="text-sm mt-1">This key will not be shown again.</p>
              <code class="block mt-2 bg-base-100 p-2 rounded text-sm break-all">
                {@revealed_key}
              </code>
            </div>
            <button phx-click="dismiss_key" class="btn btn-sm btn-ghost">Dismiss</button>
          </div>
        <% end %>

        <%!-- Create Key Form --%>
        <div class="card bg-base-200 shadow-sm mb-6">
          <div class="card-body">
            <h2 class="card-title text-lg">Create API Key</h2>
            <.form
              for={%{}}
              id="create-api-key-form"
              phx-submit="create_key"
              class="flex gap-3 mt-2 items-end"
            >
              <div class="flex-1">
                <label class="label"><span class="label-text">Label</span></label>
                <input
                  type="text"
                  name="api_key[label]"
                  placeholder="e.g. Production, Staging"
                  class="input input-bordered input-sm w-full"
                  required
                />
              </div>
              <div>
                <label class="label"><span class="label-text">Type</span></label>
                <select name="api_key[type]" class="select select-bordered select-sm">
                  <option value="publishable">Publishable</option>
                  <option value="secret">Secret</option>
                </select>
              </div>
              <button type="submit" class="btn btn-primary btn-sm">
                <.icon name="hero-plus" class="size-4" /> Create
              </button>
            </.form>
          </div>
        </div>

        <%!-- Filter Toggle --%>
        <div class="flex justify-between items-center mb-4">
          <span class="text-sm text-base-content/60">
            {length(@api_keys)} key{if length(@api_keys) != 1, do: "s", else: ""}
          </span>
          <label class="flex items-center gap-2 cursor-pointer">
            <span class="text-sm">Show revoked</span>
            <input
              type="checkbox"
              class="toggle toggle-sm"
              checked={@show_revoked}
              phx-click="toggle_revoked"
            />
          </label>
        </div>

        <%!-- Key List --%>
        <%= if @api_keys == [] do %>
          <div class="text-center py-12 text-base-content/50">
            <.icon name="hero-key" class="size-12 mx-auto mb-3 opacity-30" />
            <p>No API keys yet</p>
            <p class="text-sm mt-1">Create your first key above to get started.</p>
          </div>
        <% else %>
          <div class="space-y-3">
            <%= for key <- @api_keys do %>
              <div class={"card bg-base-200 shadow-sm #{if key.status == "revoked", do: "opacity-60"}"}>
                <div class="card-body p-4">
                  <div class="flex items-center justify-between">
                    <div>
                      <div class="flex items-center gap-2">
                        <span class="font-medium">{key.label}</span>
                        <span class={"badge badge-sm #{if key.type == "secret", do: "badge-warning", else: "badge-info"}"}>
                          {key.type}
                        </span>
                        <%= if key.status == "revoked" do %>
                          <span class="badge badge-sm badge-error">Revoked</span>
                        <% end %>
                      </div>
                      <p class="text-xs text-base-content/50 mt-1">
                        <code>{key.key_prefix}•••</code>
                        <span class="ml-2">
                          Created {Calendar.strftime(key.inserted_at, "%b %d, %Y")}
                        </span>
                      </p>
                    </div>
                    <%= if key.status == "active" do %>
                      <button
                        phx-click="revoke_key"
                        phx-value-id={key.id}
                        data-confirm="Are you sure you want to revoke this API key? This cannot be undone."
                        class="btn btn-sm btn-error btn-outline"
                      >
                        Revoke
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <%!-- No org message --%>
        <div class="card bg-base-200 shadow-sm max-w-lg">
          <div class="card-body text-center">
            <.icon name="hero-building-office" class="size-12 mx-auto mb-3 opacity-30" />
            <p class="font-medium">No organization selected</p>
            <p class="text-sm text-base-content/60 mt-1">
              Create an organization from the
              <.link navigate={~p"/dashboard"} class="link link-primary">dashboard</.link>
              to manage API keys.
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
