defmodule SyncforgeWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SyncforgeWeb, :html

  # Embed root.html.heex (the HTML skeleton)
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
              Get Started <span aria-hidden="true">&rarr;</span>
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the dashboard layout with sidebar navigation.
  """
  attr :flash, :map, required: true
  attr :current_user, :map, required: true
  attr :organizations, :list, default: []
  attr :current_org, :map, default: nil
  attr :active_nav, :atom, default: :overview

  def dashboard(assigns) do
    ~H"""
    <div class="flex h-screen bg-base-100">
      <%!-- Sidebar --%>
      <aside class="w-64 bg-base-200 border-r border-base-300 flex flex-col">
        <%!-- Logo --%>
        <div class="p-4 border-b border-base-300">
          <a href="/" class="flex items-center gap-2">
            <img src={~p"/images/logo.svg"} width="28" />
            <span class="font-bold text-lg">SyncForge</span>
          </a>
        </div>

        <%!-- Org Picker --%>
        <div class="p-3 border-b border-base-300">
          <%= if @organizations != [] do %>
            <select
              id="org-picker"
              phx-change="switch_org"
              name="org_id"
              class="select select-bordered select-sm w-full"
            >
              <%= for org <- @organizations do %>
                <option value={org.id} selected={@current_org && org.id == @current_org.id}>
                  {org.name}
                </option>
              <% end %>
            </select>
          <% else %>
            <p class="text-xs text-base-content/50 px-1">No organizations yet</p>
          <% end %>
        </div>

        <%!-- Nav Links --%>
        <nav class="flex-1 p-3 space-y-1">
          <.link
            navigate={~p"/dashboard"}
            class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors #{if @active_nav == :overview, do: "bg-primary text-primary-content", else: "hover:bg-base-300"}"}
          >
            <.icon name="hero-home" class="size-5" /> Overview
          </.link>
          <.link
            navigate={~p"/dashboard/rooms"}
            class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors #{if @active_nav == :rooms, do: "bg-primary text-primary-content", else: "hover:bg-base-300"}"}
          >
            <.icon name="hero-rectangle-group" class="size-5" /> Rooms
          </.link>
          <.link
            navigate={~p"/dashboard/api-keys"}
            class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors #{if @active_nav == :api_keys, do: "bg-primary text-primary-content", else: "hover:bg-base-300"}"}
          >
            <.icon name="hero-key" class="size-5" /> API Keys
          </.link>
          <.link
            navigate={~p"/dashboard/analytics"}
            class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors #{if @active_nav == :analytics, do: "bg-primary text-primary-content", else: "hover:bg-base-300"}"}
          >
            <.icon name="hero-chart-bar" class="size-5" /> Analytics
          </.link>
          <.link
            navigate={~p"/dashboard/logs"}
            class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors #{if @active_nav == :logs, do: "bg-primary text-primary-content", else: "hover:bg-base-300"}"}
          >
            <.icon name="hero-document-text" class="size-5" /> Logs
          </.link>
          <.link
            navigate={~p"/dashboard/billing"}
            class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium transition-colors #{if @active_nav == :billing, do: "bg-primary text-primary-content", else: "hover:bg-base-300"}"}
          >
            <.icon name="hero-credit-card" class="size-5" /> Billing
          </.link>
        </nav>

        <%!-- User section --%>
        <div class="p-3 border-t border-base-300">
          <div class="flex items-center gap-3 px-3 py-2">
            <div class="avatar placeholder">
              <div class="bg-neutral text-neutral-content rounded-full w-8">
                <span class="text-xs">
                  {String.first(@current_user.name || @current_user.email)}
                </span>
              </div>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium truncate">{@current_user.name}</p>
              <p class="text-xs text-base-content/50 truncate">{@current_user.email}</p>
            </div>
          </div>
          <.link
            href={~p"/session"}
            method="delete"
            class="flex items-center gap-3 px-3 py-2 rounded-lg text-sm hover:bg-base-300 transition-colors w-full mt-1"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="size-5" /> Log out
          </.link>
        </div>
      </aside>

      <%!-- Main Content --%>
      <main class="flex-1 overflow-auto">
        <div class="p-6 lg:p-8">
          <.flash_group flash={@flash} />
          {@inner_content}
        </div>
      </main>
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
