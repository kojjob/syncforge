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
    <header class="flex items-center justify-between px-4 py-3 sm:px-6 lg:px-8 border-b border-border">
      <div class="flex-1">
        <a href="/" class="flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold text-foreground">
            v{Application.spec(:phoenix, :vsn)}
          </span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex px-1 space-x-4 items-center">
          <li>
            <a
              href="https://phoenixframework.org/"
              class="text-sm font-medium text-muted hover:text-foreground transition-colors"
            >
              Website
            </a>
          </li>
          <li>
            <a
              href="https://github.com/phoenixframework/phoenix"
              class="text-sm font-medium text-muted hover:text-foreground transition-colors"
            >
              GitHub
            </a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a
              href="https://hexdocs.pm/phoenix/overview.html"
              class="inline-flex items-center gap-1 rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary-hover transition-colors"
            >
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
    <div class="flex h-screen bg-surface">
      <%!-- Sidebar --%>
      <aside class="w-64 border-r border-border flex flex-col bg-surface sticky top-0 h-screen">
        <div class="p-6 flex flex-col gap-8 h-full">
          <%!-- Logo --%>
          <div class="flex items-center gap-3">
            <div class="bg-primary rounded-lg p-2 text-primary-foreground flex items-center justify-center">
              <.icon name="hero-arrow-path" class="size-5" />
            </div>
            <div class="flex flex-col">
              <h1 class="text-foreground text-lg font-bold leading-tight">SyncForge</h1>
              <p class="text-muted-foreground text-xs font-medium">Dev Infrastructure</p>
            </div>
          </div>

          <%!-- Nav Links --%>
          <nav class="flex flex-col gap-1 flex-1">
            <.link
              navigate={~p"/dashboard"}
              class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm #{if @active_nav == :overview, do: "bg-primary/10 text-primary font-semibold", else: "text-muted font-medium hover:bg-surface-alt transition-colors"}"}
            >
              <.icon name="hero-squares-2x2" class="size-5" /> Overview
            </.link>
            <.link
              navigate={~p"/dashboard/rooms"}
              class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm #{if @active_nav == :rooms, do: "bg-primary/10 text-primary font-semibold", else: "text-muted font-medium hover:bg-surface-alt transition-colors"}"}
            >
              <.icon name="hero-rectangle-group" class="size-5" /> Rooms
            </.link>
            <.link
              navigate={~p"/dashboard/analytics"}
              class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm #{if @active_nav == :analytics, do: "bg-primary/10 text-primary font-semibold", else: "text-muted font-medium hover:bg-surface-alt transition-colors"}"}
            >
              <.icon name="hero-chart-bar" class="size-5" /> Metrics
            </.link>
            <.link
              navigate={~p"/dashboard/api-keys"}
              class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm #{if @active_nav == :api_keys, do: "bg-primary/10 text-primary font-semibold", else: "text-muted font-medium hover:bg-surface-alt transition-colors"}"}
            >
              <.icon name="hero-key" class="size-5" /> API Keys
            </.link>
            <.link
              navigate={~p"/dashboard/logs"}
              class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm #{if @active_nav == :logs, do: "bg-primary/10 text-primary font-semibold", else: "text-muted font-medium hover:bg-surface-alt transition-colors"}"}
            >
              <.icon name="hero-document-text" class="size-5" /> Logs
            </.link>
            <.link
              navigate={~p"/dashboard/billing"}
              class={"flex items-center gap-3 px-3 py-2 rounded-lg text-sm mt-auto #{if @active_nav == :billing, do: "bg-primary/10 text-primary font-semibold", else: "text-muted font-medium hover:bg-surface-alt transition-colors"}"}
            >
              <.icon name="hero-credit-card" class="size-5" /> Billing
            </.link>
          </nav>

          <%!-- User Section --%>
          <div class="border-t border-border pt-4">
            <div class="flex items-center gap-3">
              <div class="flex items-center justify-center bg-primary/10 text-primary rounded-full w-8 h-8 shrink-0">
                <span class="text-xs font-semibold">
                  {String.first(@current_user.name || @current_user.email)}
                </span>
              </div>
              <div class="flex flex-col overflow-hidden">
                <p class="text-sm font-bold text-foreground truncate">
                  {@current_user.name || @current_user.email}
                </p>
                <p class="text-xs text-muted-foreground truncate">
                  {if @current_org,
                    do: "#{String.capitalize(to_string(@current_org.plan_type || "free"))} Plan",
                    else: "Free Plan"}
                </p>
              </div>
            </div>
          </div>
        </div>
      </aside>

      <%!-- Main Content --%>
      <main class="flex-1 flex flex-col overflow-auto">
        <%!-- Top Bar --%>
        <header class="flex items-center justify-between border-b border-border px-8 py-4 bg-surface shrink-0">
          <div class="flex items-center gap-6">
            <%!-- Org/Project Selector --%>
            <div class="flex items-center gap-3">
              <.icon name="hero-folder" class="size-5 text-primary" />
              <%= if @organizations != [] do %>
                <select
                  id="org-picker"
                  phx-change="switch_org"
                  name="org_id"
                  class="bg-transparent border-none text-foreground text-base font-bold tracking-tight focus:ring-0 p-0 pr-8 cursor-pointer"
                >
                  <%= for org <- @organizations do %>
                    <option value={org.id} selected={@current_org && org.id == @current_org.id}>
                      {org.name}
                    </option>
                  <% end %>
                </select>
              <% else %>
                <span class="text-base font-bold text-muted-foreground">No projects</span>
              <% end %>
            </div>
            <div class="h-6 w-px bg-border"></div>
            <%!-- Search --%>
            <div class="relative flex items-center">
              <.icon
                name="hero-magnifying-glass"
                class="absolute left-3 size-4 text-muted-foreground"
              />
              <input
                class="w-64 h-9 bg-input border border-input-border rounded-lg pl-9 pr-4 text-sm text-foreground placeholder-muted-foreground focus:ring-2 focus:ring-primary/50 focus:border-primary focus:outline-none"
                placeholder="Search rooms or metrics"
              />
            </div>
          </div>
          <div class="flex items-center gap-3">
            <button class="p-2 rounded-lg bg-input text-muted hover:bg-surface-strong hover:text-foreground transition-colors">
              <.icon name="hero-bell" class="size-5" />
            </button>
            <button class="p-2 rounded-lg bg-input text-muted hover:bg-surface-strong hover:text-foreground transition-colors">
              <.icon name="hero-question-mark-circle" class="size-5" />
            </button>
            <.link
              href={~p"/session"}
              method="delete"
              class="p-2 rounded-lg bg-input text-muted hover:bg-surface-strong hover:text-foreground transition-colors"
              title="Log out"
            >
              <.icon name="hero-arrow-right-on-rectangle" class="size-5" />
            </.link>
          </div>
        </header>

        <%!-- Page Content --%>
        <div class="p-8 max-w-7xl w-full mx-auto flex-1">
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
    <div class="relative flex flex-row items-center border-2 border-border-strong bg-surface-strong rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border border-border bg-surface brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

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
