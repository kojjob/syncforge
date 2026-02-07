defmodule SyncforgeWeb.LandingLive do
  @moduledoc """
  Marketing landing page for SyncForge.

  Presents product positioning, feature highlights, developer quick start,
  pricing, and waitlist capture.
  """

  use SyncforgeWeb, :live_view

  alias Syncforge.Marketing

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "SyncForge | Real-Time Collaboration Infrastructure",
       meta_description:
         "Add real-time presence, live cursors, comments, and notifications to your app in minutes with SyncForge.",
       theme: "system",
       active_tab: "presence",
       email: ""
     )}
  end

  @impl true
  def handle_event("toggle_theme", %{"theme" => theme}, socket)
      when theme in ~w(light dark system) do
    {:noreply, assign(socket, theme: theme)}
  end

  def handle_event("toggle_theme", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def handle_event("submit_email", %{"email" => email}, socket) do
    cleaned_email = if is_binary(email), do: String.trim(email), else: ""

    case Marketing.create_waitlist_signup(%{
           email: cleaned_email,
           source: "landing_page"
         }) do
      {:ok, _signup} ->
        {:noreply,
         socket
         |> assign(email: "")
         |> put_flash(:info, "You're on the waitlist. We'll be in touch soon.")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(email: cleaned_email)
         |> put_flash(:error, waitlist_error_message(changeset))}
    end
  end

  defp waitlist_error_message(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    cond do
      "has already been taken" in Map.get(errors, :email, []) ->
        "This email is already on the waitlist."

      Map.has_key?(errors, :email) ->
        "Please enter a valid email address."

      true ->
        "We couldn't add you right now. Please try again."
    end
  end

  # Code examples for SDK integration
  defp code_example("presence") do
    """
    <span class="comment">// Initialize SyncForge and join a room</span>
    <span class="keyword">import</span> { SyncForge } <span class="keyword">from</span> <span class="string">'@syncforge/sdk'</span>

    <span class="keyword">const</span> client = <span class="keyword">new</span> <span class="function">SyncForge</span>({
      apiKey: <span class="string">process.env.SYNCFORGE_KEY</span>
    })

    <span class="keyword">const</span> room = client.<span class="function">joinRoom</span>(<span class="string">'design-review'</span>, {
      user: { id: <span class="string">'u_1024'</span>, name: <span class="string">'Riley'</span> }
    })

    <span class="comment">// Subscribe to presence changes</span>
    room.<span class="function">on</span>(<span class="string">'presence'</span>, (users) => {
      console.<span class="function">log</span>(<span class="string">'Online:'</span>, users.length)
    })
    """
  end

  defp code_example("cursors") do
    """
    <span class="comment">// Track and display live cursors</span>
    room.<span class="function">on</span>(<span class="string">'cursors'</span>, (cursors) => {
      cursors.<span class="function">forEach</span>((cursor) => {
        <span class="function">renderCursor</span>({
          id: cursor.userId,
          x: cursor.x,
          y: cursor.y,
          color: cursor.user.color
        })
      })
    })

    <span class="comment">// Push your cursor position at 60fps</span>
    window.<span class="function">addEventListener</span>(<span class="string">'pointermove'</span>, (e) => {
      room.<span class="function">updateCursor</span>({ x: e.clientX, y: e.clientY })
    })
    """
  end

  defp code_example("comments") do
    """
    <span class="comment">// Add threaded comments to any element</span>
    <span class="keyword">const</span> thread = room.<span class="function">createThread</span>({
      anchorId: <span class="string">'hero-copy'</span>,
      position: { x: 128, y: 240 }
    })

    <span class="keyword">await</span> thread.<span class="function">addComment</span>({
      body: <span class="string">'Can we tighten this headline spacing?'</span>
    })

    <span class="comment">// Subscribe to new comments</span>
    room.<span class="function">on</span>(<span class="string">'comment:new'</span>, (comment) => {
      <span class="function">showNotification</span>(comment)
    })
    """
  end

  defp code_example(_), do: code_example("presence")

  @impl true
  def render(assigns) do
    ~H"""
    <div id="landing-page" class="landing-page" data-theme={@theme} phx-hook="ThemeToggle">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <div class="bg-orb orb-a" aria-hidden="true"></div>
      <div class="bg-orb orb-b" aria-hidden="true"></div>
      <div class="grid-noise" aria-hidden="true"></div>

      <header class="topbar">
        <div class="topbar-inner">
          <a href={~p"/"} class="brand">
            <span class="brand-mark" aria-hidden="true">S</span>
            <span class="brand-text">SyncForge</span>
          </a>

          <nav class="topnav" aria-label="Primary">
            <a href="#features" class="topnav-link">Features</a>
            <a href="#developers" class="topnav-link">Developers</a>
            <a href="#pricing" class="topnav-link">Pricing</a>
            <a href={~p"/docs"} class="topnav-link">Docs</a>
          </nav>

          <div class="topbar-actions">
            <div class="theme-group" aria-label="Theme toggle">
              <button
                type="button"
                class={"theme-pill #{if @theme == "light", do: "active", else: ""}"}
                phx-click="toggle_theme"
                phx-value-theme="light"
                title="Light mode"
                aria-label="Set light theme"
                aria-pressed={@theme == "light"}
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                  <circle cx="12" cy="12" r="4"></circle>
                  <path d="M12 2v2m0 16v2M4 12H2m20 0h-2M5 5l1.5 1.5M17.5 17.5L19 19M5 19l1.5-1.5M17.5 6.5L19 5">
                  </path>
                </svg>
              </button>
              <button
                type="button"
                class={"theme-pill #{if @theme == "system", do: "active", else: ""}"}
                phx-click="toggle_theme"
                phx-value-theme="system"
                title="System preference"
                aria-label="Use system theme"
                aria-pressed={@theme == "system"}
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                  <rect x="3" y="4" width="18" height="12" rx="2"></rect>
                  <path d="M8 20h8M12 16v4"></path>
                </svg>
              </button>
              <button
                type="button"
                class={"theme-pill #{if @theme == "dark", do: "active", else: ""}"}
                phx-click="toggle_theme"
                phx-value-theme="dark"
                title="Dark mode"
                aria-label="Set dark theme"
                aria-pressed={@theme == "dark"}
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                  <path d="M21 12.8A8.9 8.9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"></path>
                </svg>
              </button>
            </div>

            <a href={~p"/login"} class="button button-ghost">Sign in</a>
            <a href={~p"/register"} class="button button-primary">Get started</a>
          </div>
        </div>
      </header>

      <main class="landing-main">
        <section class="hero" aria-labelledby="hero-title">
          <div class="hero-copy">
            <p class="eyebrow">Realtime Infrastructure for Product Teams</p>
            <h1 id="hero-title" class="display-xl">
              Collaboration made seamless <span>from first prototype to production scale.</span>
            </h1>
            <p class="hero-subtitle">
              Add real-time presence, live cursors, comments, and notifications to your app in minutes. Ship multiplayer experiences without rebuilding your stack.
            </p>

            <div class="hero-actions">
              <a href={~p"/register"} class="button button-primary">
                Start building free
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                  <path d="M5 12h14M13 5l7 7-7 7"></path>
                </svg>
              </a>
              <a href={~p"/docs"} class="button button-secondary">Read the docs</a>
            </div>

            <dl class="hero-stats" aria-label="Platform metrics">
              <div>
                <dt>Median latency</dt>
                <dd>&lt;40ms</dd>
              </div>
              <div>
                <dt>SDK install</dt>
                <dd>2 min</dd>
              </div>
              <div>
                <dt>Global uptime</dt>
                <dd>99.99%</dd>
              </div>
            </dl>
          </div>

          <aside class="hero-stage" aria-label="Live collaboration preview">
            <header class="stage-head">
              <span class="stage-dot"></span>
              <span class="stage-title">release-plan.fig</span>
              <span class="stage-pill">6 collaborators online</span>
            </header>

            <div class="stage-grid">
              <article class="stage-card reveal-1">
                <h3>Presence</h3>
                <p>Design reviewers joined from New York, Berlin, and Lagos.</p>
              </article>
              <article class="stage-card reveal-2">
                <h3>Comments</h3>
                <p>12 threaded notes resolved automatically in real time.</p>
              </article>
              <article class="stage-card reveal-3">
                <h3>Cursors</h3>
                <p>Every participant tracked at 60fps with smoothing.</p>
              </article>
              <article class="stage-card reveal-4">
                <h3>Notifications</h3>
                <p>@mentions delivered instantly across devices.</p>
              </article>
            </div>
          </aside>
        </section>

        <section class="signal-strip" aria-label="Teams using SyncForge">
          <p>Trusted by teams building collaborative products:</p>
          <div class="signal-rail">
            <span>Northstar</span>
            <span>Bricklane</span>
            <span>OrbitDesk</span>
            <span>Bluecanvas</span>
            <span>Quarry</span>
          </div>
        </section>

        <section id="features" class="features" aria-labelledby="features-title">
          <div class="section-head">
            <p class="eyebrow">Features</p>
            <h2 id="features-title" class="display-lg">
              Everything needed for multiplayer product UX
            </h2>
            <p>
              Battle-tested collaboration primitives, optimized for scale and built for developers.
            </p>
          </div>

          <div class="features-grid">
            <article class="feature-card">
              <span class="feature-kicker">01</span>
              <h3>Presence</h3>
              <p>Track participants and state changes with resilient CRDT-backed sync.</p>
              <ul>
                <li>Session metadata</li>
                <li>Join/leave events</li>
                <li>Room occupancy snapshots</li>
              </ul>
            </article>

            <article class="feature-card">
              <span class="feature-kicker">02</span>
              <h3>Live Cursors</h3>
              <p>Render labeled cursors with broadcast throttling and visual smoothing.</p>
              <ul>
                <li>60fps interpolation</li>
                <li>Low bandwidth transport</li>
                <li>Deterministic user colors</li>
              </ul>
            </article>

            <article class="feature-card">
              <span class="feature-kicker">03</span>
              <h3>Comments</h3>
              <p>Anchor discussions to specific elements and keep threads in sync instantly.</p>
              <ul>
                <li>Nested replies</li>
                <li>Mentions and reactions</li>
                <li>Resolve workflows</li>
              </ul>
            </article>

            <article class="feature-card">
              <span class="feature-kicker">04</span>
              <h3>Notifications</h3>
              <p>Deliver meaningful updates in-app, by webhook, or with batched digests.</p>
              <ul>
                <li>Unread counters</li>
                <li>Preference controls</li>
                <li>Real-time activity feed</li>
              </ul>
            </article>
          </div>
        </section>

        <section id="developers" class="developers" aria-labelledby="developers-title">
          <div class="section-head section-head-left">
            <p class="eyebrow">Developers</p>
            <h2 id="developers-title" class="display-lg">Drop-in APIs, predictable behavior</h2>
            <p>
              Start with one room. Scale to thousands of concurrent users with the same integration surface.
            </p>
          </div>

          <div class="code-shell">
            <div class="code-tabs" role="tablist" aria-label="Developer SDK examples">
              <button
                type="button"
                id="tab-presence"
                role="tab"
                aria-selected={@active_tab == "presence"}
                aria-controls="developers-code-panel"
                class={"code-tab #{if @active_tab == "presence", do: "active", else: ""}"}
                phx-click="set_tab"
                phx-value-tab="presence"
              >
                Presence
              </button>
              <button
                type="button"
                id="tab-cursors"
                role="tab"
                aria-selected={@active_tab == "cursors"}
                aria-controls="developers-code-panel"
                class={"code-tab #{if @active_tab == "cursors", do: "active", else: ""}"}
                phx-click="set_tab"
                phx-value-tab="cursors"
              >
                Cursors
              </button>
              <button
                type="button"
                id="tab-comments"
                role="tab"
                aria-selected={@active_tab == "comments"}
                aria-controls="developers-code-panel"
                class={"code-tab #{if @active_tab == "comments", do: "active", else: ""}"}
                phx-click="set_tab"
                phx-value-tab="comments"
              >
                Comments
              </button>
            </div>

            <div class="code-window">
              <div class="code-window-head">
                <span class="dot red"></span>
                <span class="dot amber"></span>
                <span class="dot green"></span>
                <span>syncforge.ts</span>
              </div>
              <div
                id="developers-code-panel"
                class="code-content"
                role="tabpanel"
                aria-labelledby={"tab-#{@active_tab}"}
              >
                <pre><%= raw(code_example(@active_tab)) %></pre>
              </div>
            </div>
          </div>
        </section>

        <section id="pricing" class="pricing" aria-labelledby="pricing-title">
          <div class="section-head">
            <p class="eyebrow">Pricing</p>
            <h2 id="pricing-title" class="display-lg">Simple plans, transparent limits</h2>
            <p>Start free and move up only when your product usage increases.</p>
          </div>

          <div class="pricing-grid">
            <article class="pricing-card">
              <h3>Free</h3>
              <p class="price"><strong>$0</strong><span>/month</span></p>
              <ul>
                <li>100 MAU</li>
                <li>5 rooms</li>
                <li>Presence & Cursors</li>
                <li>Community support</li>
              </ul>
              <a href={~p"/register"} class="button button-secondary">Get started</a>
            </article>

            <article class="pricing-card">
              <h3>Starter</h3>
              <p class="price"><strong>$49</strong><span>/month</span></p>
              <ul>
                <li>1,000 MAU</li>
                <li>10 rooms</li>
                <li>Comments</li>
                <li>Email support</li>
              </ul>
              <a href={~p"/register?plan=starter"} class="button button-secondary">Start trial</a>
            </article>

            <article class="pricing-card featured">
              <p class="plan-badge">Most popular</p>
              <h3>Pro</h3>
              <p class="price"><strong>$199</strong><span>/month</span></p>
              <ul>
                <li>10,000 MAU</li>
                <li>100 rooms</li>
                <li>Comments & Notifications</li>
                <li>Priority support</li>
              </ul>
              <a href={~p"/register?plan=pro"} class="button button-primary">Start trial</a>
            </article>

            <article class="pricing-card">
              <h3>Business</h3>
              <p class="price"><strong>$499</strong><span>/month</span></p>
              <ul>
                <li>50,000 MAU</li>
                <li>Unlimited rooms</li>
                <li>Analytics & Webhooks</li>
                <li>Dedicated support</li>
              </ul>
              <a href={~p"/contact"} class="button button-secondary">Contact sales</a>
            </article>
          </div>
        </section>

        <section class="cta-section" aria-labelledby="cta-title">
          <div class="cta-card">
            <p class="eyebrow">Early Access</p>
            <h2 id="cta-title" class="display-md">Get migration guides and launch updates</h2>
            <p>
              Join the waitlist for rollout playbooks, SDK changelogs, and implementation recipes.
            </p>

            <form class="cta-form" phx-submit="submit_email">
              <label for="cta-email" class="sr-only">Email address</label>
              <input
                id="cta-email"
                type="email"
                name="email"
                class="cta-input"
                placeholder="you@company.com"
                value={@email}
                autocomplete="email"
                required
              />
              <button type="submit" class="button button-primary">Get early access</button>
            </form>
          </div>
        </section>
      </main>

      <footer class="footer">
        <div class="footer-inner">
          <p>© 2026 SyncForge. Built with Elixir and Phoenix.</p>
          <nav aria-label="Footer links">
            <a href={~p"/docs"}>Documentation</a>
            <a href={~p"/blog"}>Blog</a>
            <a href={~p"/privacy"}>Privacy</a>
            <a href={~p"/contact"}>Contact</a>
            <a href="https://github.com/syncforge" target="_blank" rel="noopener noreferrer">
              GitHub
            </a>
          </nav>
        </div>
      </footer>
    </div>
    """
  end
end
