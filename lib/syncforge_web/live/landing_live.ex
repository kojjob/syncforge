defmodule SyncforgeWeb.LandingLive do
  @moduledoc """
  Landing page for SyncForge - Real-Time Collaboration Infrastructure.

  Features Apple-inspired minimalist design with dark/light mode support,
  animated presence indicators, and responsive layout.
  """

  use SyncforgeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      theme: "system",
      active_tab: "presence",
      email: ""
    )}
  end

  @impl true
  def handle_event("toggle_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, theme: theme)}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  @impl true
  def handle_event("submit_email", %{"email" => _email}, socket) do
    # TODO: Handle email subscription
    {:noreply,
     socket
     |> assign(email: "")
     |> put_flash(:info, "Thanks! We'll be in touch soon.")}
  end

  # Code examples for SDK integration
  defp code_example("presence") do
    """
    <span class="text-zinc-500">// Initialize SyncForge and join a room</span>
    <span class="text-purple-400">import</span> { SyncForge } <span class="text-purple-400">from</span> <span class="text-emerald-400">'@syncforge/sdk'</span>

    <span class="text-purple-400">const</span> client = <span class="text-purple-400">new</span> <span class="text-pink-400">SyncForge</span>({
      apiKey: <span class="text-emerald-400">'your-api-key'</span>
    })

    <span class="text-purple-400">const</span> room = client.<span class="text-pink-400">joinRoom</span>(<span class="text-emerald-400">'my-room'</span>, {
      user: { name: <span class="text-emerald-400">'John'</span>, avatar: <span class="text-emerald-400">'...'</span> }
    })

    <span class="text-zinc-500">// Subscribe to presence changes</span>
    room.<span class="text-pink-400">on</span>(<span class="text-emerald-400">'presence'</span>, (users) => {
      console.<span class="text-pink-400">log</span>(<span class="text-emerald-400">'Online:'</span>, users.length)
    })
    """
  end

  defp code_example("cursors") do
    """
    <span class="text-zinc-500">// Track and display live cursors</span>
    room.<span class="text-pink-400">on</span>(<span class="text-emerald-400">'cursors'</span>, (cursors) => {
      cursors.<span class="text-pink-400">forEach</span>((cursor) => {
        <span class="text-pink-400">renderCursor</span>({
          id: cursor.userId,
          x: cursor.x,
          y: cursor.y,
          name: cursor.user.name
        })
      })
    })

    <span class="text-zinc-500">// Update your cursor position</span>
    document.<span class="text-pink-400">addEventListener</span>(<span class="text-emerald-400">'mousemove'</span>, (e) => {
      room.<span class="text-pink-400">updateCursor</span>({ x: e.clientX, y: e.clientY })
    })
    """
  end

  defp code_example("comments") do
    """
    <span class="text-zinc-500">// Add threaded comments to any element</span>
    <span class="text-purple-400">const</span> thread = room.<span class="text-pink-400">createThread</span>({
      anchorId: <span class="text-emerald-400">'element-123'</span>,
      position: { x: 100, y: 200 }
    })

    <span class="text-purple-400">await</span> thread.<span class="text-pink-400">addComment</span>({
      body: <span class="text-emerald-400">'This needs more contrast'</span>
    })

    <span class="text-zinc-500">// Subscribe to new comments</span>
    room.<span class="text-pink-400">on</span>(<span class="text-emerald-400">'comment:new'</span>, (comment) => {
      <span class="text-pink-400">showNotification</span>(comment)
    })
    """
  end

  defp code_example(_), do: code_example("presence")

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="landing-page"
      class="landing-page min-h-screen bg-white dark:bg-zinc-950 text-zinc-900 dark:text-zinc-100 transition-colors duration-300"
      data-theme={@theme}
      phx-hook="ThemeToggle"
    >
      <!-- Custom Styles -->
      <style>
        @import url('https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&display=swap');

        .font-display { font-family: 'Instrument Serif', Georgia, serif; }

        @keyframes fadeInUp {
          from { opacity: 0; transform: translateY(20px); }
          to { opacity: 1; transform: translateY(0); }
        }

        @keyframes pulse-dot {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.7; transform: scale(1.1); }
        }

        @keyframes cursorMove1 {
          0%, 100% { transform: translate(20px, 40px); }
          25% { transform: translate(150px, 80px); }
          50% { transform: translate(100px, 140px); }
          75% { transform: translate(200px, 60px); }
        }

        @keyframes cursorMove2 {
          0%, 100% { transform: translate(250px, 100px); }
          33% { transform: translate(80px, 60px); }
          66% { transform: translate(180px, 160px); }
        }

        @keyframes cursorMove3 {
          0%, 100% { transform: translate(300px, 50px); }
          50% { transform: translate(50px, 120px); }
        }

        @keyframes typingBounce {
          0%, 60%, 100% { transform: translateY(0); }
          30% { transform: translateY(-4px); }
        }

        .animate-fadeInUp { animation: fadeInUp 0.6s ease-out forwards; }
        .animate-fadeInUp-delay-1 { animation: fadeInUp 0.6s ease-out 0.1s forwards; opacity: 0; }
        .animate-fadeInUp-delay-2 { animation: fadeInUp 0.6s ease-out 0.2s forwards; opacity: 0; }
        .animate-fadeInUp-delay-3 { animation: fadeInUp 0.6s ease-out 0.3s forwards; opacity: 0; }
        .animate-fadeInUp-delay-4 { animation: fadeInUp 0.8s ease-out 0.4s forwards; opacity: 0; }

        .pulse-dot { animation: pulse-dot 2s ease-in-out infinite; }
        .cursor-1 { animation: cursorMove1 8s ease-in-out infinite; }
        .cursor-2 { animation: cursorMove2 10s ease-in-out infinite; }
        .cursor-3 { animation: cursorMove3 7s ease-in-out infinite; }

        .typing-dot { animation: typingBounce 1.4s ease-in-out infinite; }
        .typing-dot:nth-child(2) { animation-delay: 0.2s; }
        .typing-dot:nth-child(3) { animation-delay: 0.4s; }
      </style>

      <!-- Navigation -->
      <nav class="fixed top-0 left-0 right-0 z-50 bg-white/90 dark:bg-zinc-950/90 backdrop-blur-xl border-b border-zinc-200 dark:border-zinc-800">
        <div class="max-w-6xl mx-auto px-6 py-4 flex items-center justify-between">
          <a href="/" class="flex items-center gap-2 font-semibold text-lg text-zinc-900 dark:text-white">
            <div class="w-8 h-8 bg-gradient-to-br from-emerald-500 to-purple-600 rounded-lg flex items-center justify-center">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
                <path d="M12 2L2 7l10 5 10-5-10-5z"/>
                <path d="M2 17l10 5 10-5"/>
                <path d="M2 12l10 5 10-5"/>
              </svg>
            </div>
            SyncForge
          </a>

          <div class="hidden md:flex gap-8">
            <a href="#features" class="text-sm text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white transition-colors">Features</a>
            <a href="#developers" class="text-sm text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white transition-colors">Developers</a>
            <a href="#pricing" class="text-sm text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white transition-colors">Pricing</a>
            <a href="/docs" class="text-sm text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white transition-colors">Docs</a>
          </div>

          <div class="flex items-center gap-3">
            <!-- Theme Toggle -->
            <div class="flex items-center gap-1 p-1 bg-zinc-100 dark:bg-zinc-800 rounded-full border border-zinc-200 dark:border-zinc-700">
              <button
                class={"p-1.5 rounded-full transition-all " <> if(@theme == "light", do: "bg-white dark:bg-zinc-700 shadow-sm text-zinc-900 dark:text-white", else: "text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300")}
                phx-click="toggle_theme"
                phx-value-theme="light"
                title="Light mode"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <circle cx="12" cy="12" r="5"/>
                  <path d="M12 1v2m0 18v2M4.22 4.22l1.42 1.42m12.72 12.72l1.42 1.42M1 12h2m18 0h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/>
                </svg>
              </button>
              <button
                class={"p-1.5 rounded-full transition-all " <> if(@theme == "system", do: "bg-white dark:bg-zinc-700 shadow-sm text-zinc-900 dark:text-white", else: "text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300")}
                phx-click="toggle_theme"
                phx-value-theme="system"
                title="System preference"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect x="2" y="3" width="20" height="14" rx="2"/>
                  <path d="M8 21h8m-4-4v4"/>
                </svg>
              </button>
              <button
                class={"p-1.5 rounded-full transition-all " <> if(@theme == "dark", do: "bg-white dark:bg-zinc-700 shadow-sm text-zinc-900 dark:text-white", else: "text-zinc-500 hover:text-zinc-700 dark:hover:text-zinc-300")}
                phx-click="toggle_theme"
                phx-value-theme="dark"
                title="Dark mode"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>
                </svg>
              </button>
            </div>

            <a href="/login" class="hidden sm:block text-sm text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white px-3 py-2 transition-colors">Sign in</a>
            <a href="/signup" class="text-sm font-medium bg-purple-600 hover:bg-purple-700 text-white px-4 py-2 rounded-full transition-colors">Get started</a>
          </div>
        </div>
      </nav>

      <!-- Hero Section -->
      <section class="pt-32 pb-16 px-6 max-w-6xl mx-auto">
        <div class="text-center max-w-3xl mx-auto mb-16">
          <div class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-50 dark:bg-emerald-950/50 border border-emerald-200 dark:border-emerald-800 rounded-full mb-8 animate-fadeInUp">
            <span class="w-2 h-2 bg-emerald-500 rounded-full pulse-dot"></span>
            <span class="text-xs font-semibold tracking-wide text-emerald-700 dark:text-emerald-400">Now in Public Beta</span>
          </div>

          <h1 class="font-display text-5xl md:text-6xl lg:text-7xl font-normal leading-tight mb-6 animate-fadeInUp-delay-1">
            Collaboration<br/><em class="text-emerald-600 dark:text-emerald-400">made seamless</em>
          </h1>

          <p class="text-lg md:text-xl text-zinc-600 dark:text-zinc-400 max-w-xl mx-auto mb-10 leading-relaxed animate-fadeInUp-delay-2">
            Add real-time presence, live cursors, and collaboration features to your app in minutes. Built on the BEAM for legendary reliability.
          </p>

          <div class="flex flex-wrap gap-4 justify-center animate-fadeInUp-delay-3">
            <a href="/signup" class="inline-flex items-center gap-2 bg-purple-600 hover:bg-purple-700 text-white font-medium px-6 py-3 rounded-full transition-all hover:-translate-y-0.5">
              Start building free
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M5 12h14m-7-7l7 7-7 7"/>
              </svg>
            </a>
            <a href="/docs" class="inline-flex items-center gap-2 bg-zinc-100 dark:bg-zinc-800 hover:bg-zinc-200 dark:hover:bg-zinc-700 text-zinc-900 dark:text-white font-medium px-6 py-3 rounded-full border border-zinc-200 dark:border-zinc-700 transition-all">
              Read the docs
            </a>
          </div>
        </div>

        <!-- Interactive Demo -->
        <div class="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl p-6 shadow-xl dark:shadow-2xl animate-fadeInUp-delay-4">
          <div class="flex items-center justify-between mb-6 pb-4 border-b border-zinc-200 dark:border-zinc-800">
            <span class="text-sm font-medium text-zinc-900 dark:text-white">design-review.fig</span>
            <div class="flex items-center">
              <div class="w-7 h-7 rounded-full bg-pink-400 border-2 border-white dark:border-zinc-900 flex items-center justify-center text-[10px] font-semibold text-white">SK</div>
              <div class="w-7 h-7 rounded-full bg-blue-400 border-2 border-white dark:border-zinc-900 flex items-center justify-center text-[10px] font-semibold text-white -ml-2">JD</div>
              <div class="w-7 h-7 rounded-full bg-emerald-400 border-2 border-white dark:border-zinc-900 flex items-center justify-center text-[10px] font-semibold text-white -ml-2">AM</div>
              <div class="w-7 h-7 rounded-full bg-zinc-200 dark:bg-zinc-700 border-2 border-white dark:border-zinc-900 flex items-center justify-center text-[10px] font-medium text-zinc-600 dark:text-zinc-400 -ml-2">+3</div>
            </div>
          </div>

          <div class="relative bg-zinc-50 dark:bg-zinc-800/50 rounded-lg p-6 min-h-[200px]">
            <div class="font-mono text-sm text-zinc-600 dark:text-zinc-400 leading-loose">
              <p class="mb-4">// Real-time collaboration in action</p>
              <p class="mb-2">The hero section needs more <span class="bg-purple-100 dark:bg-purple-900/50 border-b-2 border-purple-500 px-0.5">visual impact</span>.</p>
              <p class="mb-2">Let's add animated presence indicators and</p>
              <p class="mb-4">make the CTA buttons more prominent.</p>

              <div class="inline-flex items-center gap-1 px-3 py-1.5 bg-white dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 rounded-full">
                <div class="w-1 h-1 bg-zinc-400 rounded-full typing-dot"></div>
                <div class="w-1 h-1 bg-zinc-400 rounded-full typing-dot"></div>
                <div class="w-1 h-1 bg-zinc-400 rounded-full typing-dot"></div>
                <span class="text-xs text-zinc-500 ml-2">Sarah is typing...</span>
              </div>
            </div>

            <!-- Animated Cursors -->
            <div class="absolute cursor-1 pointer-events-none z-10">
              <div class="w-0 h-0 border-l-[6px] border-r-[6px] border-t-[12px] border-l-transparent border-r-transparent border-t-pink-400 -rotate-45"></div>
              <span class="absolute top-2.5 left-2 px-2 py-0.5 text-[10px] font-medium text-white bg-pink-400 rounded whitespace-nowrap">Sarah K.</span>
            </div>
            <div class="absolute cursor-2 pointer-events-none z-10">
              <div class="w-0 h-0 border-l-[6px] border-r-[6px] border-t-[12px] border-l-transparent border-r-transparent border-t-blue-400 -rotate-45"></div>
              <span class="absolute top-2.5 left-2 px-2 py-0.5 text-[10px] font-medium text-white bg-blue-400 rounded whitespace-nowrap">John D.</span>
            </div>
            <div class="absolute cursor-3 pointer-events-none z-10">
              <div class="w-0 h-0 border-l-[6px] border-r-[6px] border-t-[12px] border-l-transparent border-r-transparent border-t-emerald-400 -rotate-45"></div>
              <span class="absolute top-2.5 left-2 px-2 py-0.5 text-[10px] font-medium text-white bg-emerald-400 rounded whitespace-nowrap">Alex M.</span>
            </div>
          </div>
        </div>
      </section>

      <!-- Features Section -->
      <section id="features" class="py-24 px-6 max-w-6xl mx-auto">
        <div class="text-center max-w-2xl mx-auto mb-16">
          <span class="text-xs font-semibold tracking-widest text-emerald-600 dark:text-emerald-400 uppercase mb-4 block">Features</span>
          <h2 class="font-display text-3xl md:text-4xl lg:text-5xl mb-4">Everything you need for real-time collaboration</h2>
          <p class="text-zinc-600 dark:text-zinc-400">Battle-tested primitives that scale from prototype to production.</p>
        </div>

        <div class="grid md:grid-cols-2 gap-6">
          <!-- Feature Card 1 -->
          <div class="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl p-8 shadow-sm hover:shadow-lg dark:hover:shadow-2xl hover:border-emerald-300 dark:hover:border-emerald-700 transition-all hover:-translate-y-1">
            <div class="w-12 h-12 bg-emerald-100 dark:bg-emerald-900/50 rounded-xl flex items-center justify-center mb-6 text-emerald-600 dark:text-emerald-400">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="3"/>
                <circle cx="12" cy="12" r="8" stroke-dasharray="4 2"/>
              </svg>
            </div>
            <h3 class="font-display text-xl mb-3 text-zinc-900 dark:text-white">Presence Tracking</h3>
            <p class="text-zinc-600 dark:text-zinc-400 mb-6 leading-relaxed">
              Know who's online, what they're viewing, and what they're doing. CRDT-based sync ensures consistency across distributed nodes.
            </p>
            <div class="flex gap-8 pt-4 border-t border-zinc-100 dark:border-zinc-800">
              <div>
                <span class="font-mono text-xl font-semibold text-emerald-600 dark:text-emerald-400">&lt;50ms</span>
                <span class="text-xs text-zinc-500 block mt-1">Sync latency</span>
              </div>
              <div>
                <span class="font-mono text-xl font-semibold text-emerald-600 dark:text-emerald-400">∞</span>
                <span class="text-xs text-zinc-500 block mt-1">Concurrent users</span>
              </div>
            </div>
          </div>

          <!-- Feature Card 2 -->
          <div class="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl p-8 shadow-sm hover:shadow-lg dark:hover:shadow-2xl hover:border-emerald-300 dark:hover:border-emerald-700 transition-all hover:-translate-y-1">
            <div class="w-12 h-12 bg-emerald-100 dark:bg-emerald-900/50 rounded-xl flex items-center justify-center mb-6 text-emerald-600 dark:text-emerald-400">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M3 3l7.07 16.97 2.51-7.39 7.39-2.51L3 3z"/>
                <path d="M13 13l6 6"/>
              </svg>
            </div>
            <h3 class="font-display text-xl mb-3 text-zinc-900 dark:text-white">Live Cursors</h3>
            <p class="text-zinc-600 dark:text-zinc-400 mb-6 leading-relaxed">
              See where everyone is working with smooth, labeled cursors. Automatic throttling keeps bandwidth efficient.
            </p>
            <div class="flex gap-8 pt-4 border-t border-zinc-100 dark:border-zinc-800">
              <div>
                <span class="font-mono text-xl font-semibold text-emerald-600 dark:text-emerald-400">&lt;30ms</span>
                <span class="text-xs text-zinc-500 block mt-1">Broadcast time</span>
              </div>
              <div>
                <span class="font-mono text-xl font-semibold text-emerald-600 dark:text-emerald-400">60fps</span>
                <span class="text-xs text-zinc-500 block mt-1">Smoothing</span>
              </div>
            </div>
          </div>

          <!-- Feature Card 3 -->
          <div class="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl p-8 shadow-sm hover:shadow-lg dark:hover:shadow-2xl hover:border-emerald-300 dark:hover:border-emerald-700 transition-all hover:-translate-y-1">
            <div class="w-12 h-12 bg-emerald-100 dark:bg-emerald-900/50 rounded-xl flex items-center justify-center mb-6 text-emerald-600 dark:text-emerald-400">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
              </svg>
            </div>
            <h3 class="font-display text-xl mb-3 text-zinc-900 dark:text-white">Threaded Comments</h3>
            <p class="text-zinc-600 dark:text-zinc-400 mb-6 leading-relaxed">
              Pin discussions to any element. Support for replies, mentions, reactions, and resolution tracking.
            </p>
            <div class="flex gap-8 pt-4 border-t border-zinc-100 dark:border-zinc-800">
              <div>
                <span class="font-mono text-xl font-semibold text-emerald-600 dark:text-emerald-400">Real-time</span>
                <span class="text-xs text-zinc-500 block mt-1">Sync</span>
              </div>
              <div>
                <span class="font-mono text-xl font-semibold text-emerald-600 dark:text-emerald-400">@mentions</span>
                <span class="text-xs text-zinc-500 block mt-1">Built-in</span>
              </div>
            </div>
          </div>

          <!-- Feature Card 4 -->
          <div class="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl p-8 shadow-sm hover:shadow-lg dark:hover:shadow-2xl hover:border-emerald-300 dark:hover:border-emerald-700 transition-all hover:-translate-y-1">
            <div class="w-12 h-12 bg-emerald-100 dark:bg-emerald-900/50 rounded-xl flex items-center justify-center mb-6 text-emerald-600 dark:text-emerald-400">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
                <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
              </svg>
            </div>
            <h3 class="font-display text-xl mb-3 text-zinc-900 dark:text-white">Notifications</h3>
            <p class="text-zinc-600 dark:text-zinc-400 mb-6 leading-relaxed">
              Real-time alerts with customizable delivery. Activity feeds, @mentions, and smart batching included.
            </p>
            <div class="flex gap-8 pt-4 border-t border-zinc-100 dark:border-zinc-800">
              <div>
                <span class="font-mono text-xl font-semibold text-emerald-600 dark:text-emerald-400">Instant</span>
                <span class="text-xs text-zinc-500 block mt-1">Delivery</span>
              </div>
              <div>
                <span class="font-mono text-xl font-semibold text-emerald-600 dark:text-emerald-400">Webhooks</span>
                <span class="text-xs text-zinc-500 block mt-1">Supported</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Code Section -->
      <section id="developers" class="py-24 px-6 bg-zinc-50 dark:bg-zinc-900/50">
        <div class="max-w-6xl mx-auto">
          <div class="text-center max-w-2xl mx-auto mb-16">
            <span class="text-xs font-semibold tracking-widest text-emerald-600 dark:text-emerald-400 uppercase mb-4 block">For Developers</span>
            <h2 class="font-display text-3xl md:text-4xl lg:text-5xl mb-4">Ship collaboration features in minutes</h2>
            <p class="text-zinc-600 dark:text-zinc-400">Clean APIs, type-safe SDKs, and comprehensive documentation.</p>
          </div>

          <div class="flex gap-2 mb-6 overflow-x-auto pb-2">
            <button
              class={"px-4 py-2 rounded-lg font-mono text-sm border transition-all " <> if(@active_tab == "presence", do: "bg-emerald-600 border-emerald-600 text-white", else: "bg-white dark:bg-zinc-800 border-zinc-200 dark:border-zinc-700 text-zinc-600 dark:text-zinc-400 hover:border-zinc-300 dark:hover:border-zinc-600")}
              phx-click="set_tab"
              phx-value-tab="presence"
            >
              Presence
            </button>
            <button
              class={"px-4 py-2 rounded-lg font-mono text-sm border transition-all " <> if(@active_tab == "cursors", do: "bg-emerald-600 border-emerald-600 text-white", else: "bg-white dark:bg-zinc-800 border-zinc-200 dark:border-zinc-700 text-zinc-600 dark:text-zinc-400 hover:border-zinc-300 dark:hover:border-zinc-600")}
              phx-click="set_tab"
              phx-value-tab="cursors"
            >
              Cursors
            </button>
            <button
              class={"px-4 py-2 rounded-lg font-mono text-sm border transition-all " <> if(@active_tab == "comments", do: "bg-emerald-600 border-emerald-600 text-white", else: "bg-white dark:bg-zinc-800 border-zinc-200 dark:border-zinc-700 text-zinc-600 dark:text-zinc-400 hover:border-zinc-300 dark:hover:border-zinc-600")}
              phx-click="set_tab"
              phx-value-tab="comments"
            >
              Comments
            </button>
          </div>

          <div class="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-xl overflow-hidden shadow-sm">
            <div class="flex items-center gap-2 px-4 py-3 bg-zinc-50 dark:bg-zinc-800/50 border-b border-zinc-200 dark:border-zinc-800">
              <div class="w-3 h-3 rounded-full bg-red-400"></div>
              <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
              <div class="w-3 h-3 rounded-full bg-green-400"></div>
            </div>
            <div class="p-6 overflow-x-auto">
              <pre class="font-mono text-sm leading-loose text-zinc-800 dark:text-zinc-200"><%= raw(code_example(@active_tab)) %></pre>
            </div>
          </div>
        </div>
      </section>

      <!-- Pricing Section -->
      <section id="pricing" class="py-24 px-6 max-w-6xl mx-auto">
        <div class="text-center max-w-2xl mx-auto mb-16">
          <span class="text-xs font-semibold tracking-widest text-emerald-600 dark:text-emerald-400 uppercase mb-4 block">Pricing</span>
          <h2 class="font-display text-3xl md:text-4xl lg:text-5xl mb-4">Simple, predictable pricing</h2>
          <p class="text-zinc-600 dark:text-zinc-400">Start free, scale as you grow. No surprise bills.</p>
        </div>

        <div class="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
          <!-- Free -->
          <div class="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl p-6 shadow-sm hover:shadow-lg transition-all hover:-translate-y-1 flex flex-col">
            <span class="font-semibold text-zinc-900 dark:text-white mb-2">Free</span>
            <div class="flex items-baseline gap-1 mb-2">
              <span class="font-display text-4xl text-zinc-900 dark:text-white">$0</span>
              <span class="text-sm text-zinc-500">/month</span>
            </div>
            <p class="text-sm text-zinc-600 dark:text-zinc-400 mb-6 pb-6 border-b border-zinc-100 dark:border-zinc-800">Perfect for trying things out</p>
            <ul class="space-y-3 mb-8 flex-grow">
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                100 monthly active users
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                5 rooms
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                Presence & Cursors
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                Community support
              </li>
            </ul>
            <a href="/signup" class="w-full text-center py-3 rounded-full border border-zinc-200 dark:border-zinc-700 text-zinc-900 dark:text-white font-medium hover:bg-zinc-50 dark:hover:bg-zinc-800 transition-colors">Get started</a>
          </div>

          <!-- Starter -->
          <div class="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl p-6 shadow-sm hover:shadow-lg transition-all hover:-translate-y-1 flex flex-col">
            <span class="font-semibold text-zinc-900 dark:text-white mb-2">Starter</span>
            <div class="flex items-baseline gap-1 mb-2">
              <span class="font-display text-4xl text-zinc-900 dark:text-white">$49</span>
              <span class="text-sm text-zinc-500">/month</span>
            </div>
            <p class="text-sm text-zinc-600 dark:text-zinc-400 mb-6 pb-6 border-b border-zinc-100 dark:border-zinc-800">For small teams getting started</p>
            <ul class="space-y-3 mb-8 flex-grow">
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                1,000 monthly active users
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                10 rooms
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                Everything in Free
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                Email support
              </li>
            </ul>
            <a href="/signup?plan=starter" class="w-full text-center py-3 rounded-full border border-zinc-200 dark:border-zinc-700 text-zinc-900 dark:text-white font-medium hover:bg-zinc-50 dark:hover:bg-zinc-800 transition-colors">Start trial</a>
          </div>

          <!-- Pro (Featured) -->
          <div class="bg-white dark:bg-zinc-900 border-2 border-emerald-500 rounded-2xl p-6 shadow-lg relative hover:shadow-xl transition-all hover:-translate-y-1 flex flex-col">
            <span class="absolute -top-3 left-1/2 -translate-x-1/2 bg-emerald-500 text-white text-xs font-semibold px-3 py-1 rounded-full">Most Popular</span>
            <span class="font-semibold text-zinc-900 dark:text-white mb-2">Pro</span>
            <div class="flex items-baseline gap-1 mb-2">
              <span class="font-display text-4xl text-zinc-900 dark:text-white">$199</span>
              <span class="text-sm text-zinc-500">/month</span>
            </div>
            <p class="text-sm text-zinc-600 dark:text-zinc-400 mb-6 pb-6 border-b border-zinc-100 dark:border-zinc-800">For growing products</p>
            <ul class="space-y-3 mb-8 flex-grow">
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                10,000 monthly active users
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                100 rooms
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                Comments & Notifications
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                Priority support
              </li>
            </ul>
            <a href="/signup?plan=pro" class="w-full text-center py-3 rounded-full bg-purple-600 hover:bg-purple-700 text-white font-medium transition-colors">Start trial</a>
          </div>

          <!-- Business -->
          <div class="bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl p-6 shadow-sm hover:shadow-lg transition-all hover:-translate-y-1 flex flex-col">
            <span class="font-semibold text-zinc-900 dark:text-white mb-2">Business</span>
            <div class="flex items-baseline gap-1 mb-2">
              <span class="font-display text-4xl text-zinc-900 dark:text-white">$499</span>
              <span class="text-sm text-zinc-500">/month</span>
            </div>
            <p class="text-sm text-zinc-600 dark:text-zinc-400 mb-6 pb-6 border-b border-zinc-100 dark:border-zinc-800">For scale and custom needs</p>
            <ul class="space-y-3 mb-8 flex-grow">
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                50,000 monthly active users
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                Unlimited rooms
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                Voice rooms & Analytics
              </li>
              <li class="flex items-start gap-3 text-sm text-zinc-600 dark:text-zinc-400">
                <svg class="w-4 h-4 text-emerald-500 mt-0.5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                Dedicated support
              </li>
            </ul>
            <a href="/contact" class="w-full text-center py-3 rounded-full border border-zinc-200 dark:border-zinc-700 text-zinc-900 dark:text-white font-medium hover:bg-zinc-50 dark:hover:bg-zinc-800 transition-colors">Contact sales</a>
          </div>
        </div>
      </section>

      <!-- CTA Section -->
      <section class="py-24 px-6 bg-zinc-50 dark:bg-zinc-900/50">
        <div class="max-w-xl mx-auto text-center">
          <h2 class="font-display text-3xl md:text-4xl mb-4">Ready to build?</h2>
          <p class="text-zinc-600 dark:text-zinc-400 mb-8">
            Join hundreds of developers shipping real-time features with SyncForge.
          </p>
          <form class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto" phx-submit="submit_email">
            <input
              type="email"
              name="email"
              class="flex-grow px-4 py-3 bg-white dark:bg-zinc-800 border border-zinc-200 dark:border-zinc-700 rounded-full text-zinc-900 dark:text-white placeholder-zinc-500 focus:outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500"
              placeholder="Enter your email"
              value={@email}
              required
            />
            <button type="submit" class="px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white font-medium rounded-full transition-colors whitespace-nowrap">Get early access</button>
          </form>
        </div>
      </section>

      <!-- Footer -->
      <footer class="py-12 px-6 border-t border-zinc-200 dark:border-zinc-800">
        <div class="max-w-6xl mx-auto flex flex-col md:flex-row justify-between items-center gap-6">
          <p class="text-sm text-zinc-500">© 2026 SyncForge. Built with Elixir & Phoenix.</p>
          <nav class="flex gap-8">
            <a href="/docs" class="text-sm text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white transition-colors">Documentation</a>
            <a href="/blog" class="text-sm text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white transition-colors">Blog</a>
            <a href="https://github.com/syncforge" class="text-sm text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white transition-colors">GitHub</a>
            <a href="/privacy" class="text-sm text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white transition-colors">Privacy</a>
          </nav>
        </div>
      </footer>
    </div>
    """
  end
end
