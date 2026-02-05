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
    <span class="text-purple-600 dark:text-purple-400">import</span> { SyncForge } <span class="text-purple-600 dark:text-purple-400">from</span> <span class="text-emerald-600 dark:text-emerald-400">'@syncforge/sdk'</span>

    <span class="text-purple-600 dark:text-purple-400">const</span> client = <span class="text-purple-600 dark:text-purple-400">new</span> <span class="text-pink-600 dark:text-pink-400">SyncForge</span>({
      apiKey: <span class="text-emerald-600 dark:text-emerald-400">'your-api-key'</span>
    })

    <span class="text-purple-600 dark:text-purple-400">const</span> room = client.<span class="text-pink-600 dark:text-pink-400">joinRoom</span>(<span class="text-emerald-600 dark:text-emerald-400">'my-room'</span>, {
      user: { name: <span class="text-emerald-600 dark:text-emerald-400">'John'</span>, avatar: <span class="text-emerald-600 dark:text-emerald-400">'...'</span> }
    })

    <span class="text-zinc-500">// Subscribe to presence changes</span>
    room.<span class="text-pink-600 dark:text-pink-400">on</span>(<span class="text-emerald-600 dark:text-emerald-400">'presence'</span>, (users) => {
      console.<span class="text-pink-600 dark:text-pink-400">log</span>(<span class="text-emerald-600 dark:text-emerald-400">'Online:'</span>, users.length)
    })
    """
  end

  defp code_example("cursors") do
    """
    <span class="text-zinc-500">// Track and display live cursors</span>
    room.<span class="text-pink-600 dark:text-pink-400">on</span>(<span class="text-emerald-600 dark:text-emerald-400">'cursors'</span>, (cursors) => {
      cursors.<span class="text-pink-600 dark:text-pink-400">forEach</span>((cursor) => {
        <span class="text-pink-600 dark:text-pink-400">renderCursor</span>({
          id: cursor.userId,
          x: cursor.x,
          y: cursor.y,
          name: cursor.user.name
        })
      })
    })

    <span class="text-zinc-500">// Update your cursor position</span>
    document.<span class="text-pink-600 dark:text-pink-400">addEventListener</span>(<span class="text-emerald-600 dark:text-emerald-400">'mousemove'</span>, (e) => {
      room.<span class="text-pink-600 dark:text-pink-400">updateCursor</span>({ x: e.clientX, y: e.clientY })
    })
    """
  end

  defp code_example("comments") do
    """
    <span class="text-zinc-500">// Add threaded comments to any element</span>
    <span class="text-purple-600 dark:text-purple-400">const</span> thread = room.<span class="text-pink-600 dark:text-pink-400">createThread</span>({
      anchorId: <span class="text-emerald-600 dark:text-emerald-400">'element-123'</span>,
      position: { x: 100, y: 200 }
    })

    <span class="text-purple-600 dark:text-purple-400">await</span> thread.<span class="text-pink-600 dark:text-pink-400">addComment</span>({
      body: <span class="text-emerald-600 dark:text-emerald-400">'This needs more contrast'</span>
    })

    <span class="text-zinc-500">// Subscribe to new comments</span>
    room.<span class="text-pink-600 dark:text-pink-400">on</span>(<span class="text-emerald-600 dark:text-emerald-400">'comment:new'</span>, (comment) => {
      <span class="text-pink-600 dark:text-pink-400">showNotification</span>(comment)
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
      <style>
        @keyframes aurora {
          0% { background-position: 50% 50%, 50% 50%; }
          100% { background-position: 350% 50%, 350% 50%; }
        }

        @keyframes float {
          0% { transform: translateY(0px); }
          50% { transform: translateY(-20px); }
          100% { transform: translateY(0px); }
        }

        @keyframes pulse-glow {
          0%, 100% { opacity: 0.5; transform: scale(1); }
          50% { opacity: 0.8; transform: scale(1.05); }
        }

        .aurora-bg {
          background-image:
            radial-gradient(circle at 100% 100%, rgba(16, 185, 129, 0.15) 0%, transparent 50%),
            radial-gradient(circle at 0% 0%, rgba(147, 51, 234, 0.15) 0%, transparent 50%);
        }

        .animate-float { animation: float 6s ease-in-out infinite; }
        .animate-float-delayed { animation: float 6s ease-in-out 3s infinite; }
        .animate-pulse-glow { animation: pulse-glow 4s ease-in-out infinite; }
      </style>

      <!-- Floating Nav -->
      <nav class="fixed top-6 left-0 right-0 z-50 flex justify-center px-6">
        <div class="bg-white/10 dark:bg-zinc-900/10 backdrop-blur-xl border border-white/20 dark:border-white/5 rounded-full px-6 py-3 shadow-2xl flex items-center gap-8 animate-float">
          <a href="/" class="flex items-center gap-2 font-bold text-lg text-zinc-900 dark:text-white">
            <div class="w-8 h-8 rounded-lg bg-gradient-to-br from-emerald-400 to-purple-500 flex items-center justify-center p-0.5">
              <div class="w-full h-full bg-white dark:bg-zinc-950 rounded-[5px] flex items-center justify-center">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="url(#logo-grad)" stroke-width="3">
                  <defs>
                    <linearGradient id="logo-grad" x1="0" y1="0" x2="24" y2="24">
                      <stop offset="0%" stop-color="#34D399"/>
                      <stop offset="100%" stop-color="#A855F7"/>
                    </linearGradient>
                  </defs>
                  <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
                </svg>
              </div>
            </div>
            SyncForge
          </a>

          <div class="hidden md:flex gap-6 text-sm font-medium">
            <a href="#features" class="text-zinc-600 dark:text-zinc-400 hover:text-emerald-500 transition-colors">Features</a>
            <a href="#developers" class="text-zinc-600 dark:text-zinc-400 hover:text-emerald-500 transition-colors">Developers</a>
            <a href="#pricing" class="text-zinc-600 dark:text-zinc-400 hover:text-emerald-500 transition-colors">Pricing</a>
          </div>

          <div class="flex items-center gap-3 pl-4 border-l border-zinc-200 dark:border-white/10">
            <button
              class="p-2 rounded-full text-zinc-500 hover:text-zinc-900 dark:hover:text-white transition-colors"
              phx-click="toggle_theme"
              phx-value-theme={if @theme == "dark", do: "light", else: "dark"}
            >
              <svg :if={@theme != "dark"} width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
              <svg :if={@theme == "dark"} width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><path d="M12 1v2m0 18v2M4.22 4.22l1.42 1.42m12.72 12.72l1.42 1.42M1 12h2m18 0h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>
            </button>
            <a href="/login" class="text-sm font-medium text-zinc-900 dark:text-white hover:text-emerald-500 transition-colors">Sign in</a>
            <a href="/signup" class="bg-zinc-900 dark:bg-white text-white dark:text-black px-4 py-2 rounded-full text-sm font-medium hover:scale-105 transition-transform">Get Started</a>
          </div>
        </div>
      </nav>

      <!-- Hero Section -->
      <section class="relative pt-48 pb-32 px-6 overflow-hidden">
        <!-- Background Effects -->
        <div class="absolute inset-0 aurora-bg opacity-30 dark:opacity-20 pointer-events-none"></div>

        <div class="max-w-7xl mx-auto relative z-10 grid lg:grid-cols-2 gap-16 items-center">
          <div class="text-center lg:text-left">
            <div class="inline-flex items-center gap-2 px-3 py-1 bg-emerald-500/10 border border-emerald-500/20 rounded-full mb-8 backdrop-blur-sm">
              <span class="w-2 h-2 bg-emerald-500 rounded-full animate-pulse-glow"></span>
              <span class="text-xs font-semibold tracking-wide text-emerald-600 dark:text-emerald-400 uppercase">Public Beta</span>
            </div>

            <h1 class="text-6xl md:text-7xl lg:text-8xl font-bold tracking-tight mb-8 bg-clip-text text-transparent bg-gradient-to-r from-zinc-900 via-zinc-900 to-zinc-500 dark:from-white dark:via-white dark:to-zinc-500">
              Sync like <br/> it's <span class="bg-gradient-to-r from-emerald-400 to-purple-500 bg-clip-text text-transparent">magic.</span>
            </h1>

            <p class="text-xl text-zinc-600 dark:text-zinc-400 mb-10 leading-relaxed max-w-2xl lg:ml-0 mx-auto">
              Add real-time presence, live cursors, and collaborative state to your Phoenix app in minutes. powered by the BEAM.
            </p>

            <div class="flex flex-wrap gap-4 justify-center lg:justify-start">
              <a href="/signup" class="bg-zinc-900 dark:bg-white text-white dark:text-black px-8 py-4 rounded-full font-semibold text-lg hover:scale-105 transition-transform duration-300 shadow-lg shadow-emerald-500/10">
                Start Building Free
              </a>
              <a href="/docs" class="px-8 py-4 rounded-full font-semibold text-lg border border-zinc-200 dark:border-white/10 hover:bg-zinc-50 dark:hover:bg-white/5 transition-colors text-zinc-900 dark:text-white">
                Read Documentation
              </a>
            </div>
          </div>

          <!-- 3D Interactive Mockup -->
          <div class="relative lg:-mr-20 animate-float-delayed perspective-1000">
            <div class="relative bg-white dark:bg-zinc-900/80 backdrop-blur-xl border border-zinc-200 dark:border-white/10 rounded-2xl p-6 shadow-2xl transform rotate-y-12 rotate-x-6 hover:rotate-0 transition-transform duration-700 ease-out group">
              <!-- Glow behind -->
              <div class="absolute -inset-10 bg-gradient-to-r from-emerald-500/20 to-purple-500/20 blur-3xl rounded-full opacity-50 -z-10 group-hover:opacity-75 transition-opacity"></div>

              <div class="flex items-center justify-between mb-8 pb-4 border-b border-zinc-100 dark:border-white/5">
                <div class="flex gap-2">
                  <div class="w-3 h-3 rounded-full bg-red-400"></div>
                  <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
                  <div class="w-3 h-3 rounded-full bg-green-400"></div>
                </div>
                <div class="flex -space-x-2">
                  <div class="w-8 h-8 rounded-full bg-pink-500 border-2 border-white dark:border-zinc-900 flex items-center justify-center text-white text-xs font-bold">S</div>
                  <div class="w-8 h-8 rounded-full bg-purple-500 border-2 border-white dark:border-zinc-900 flex items-center justify-center text-white text-xs font-bold">M</div>
                  <div class="w-8 h-8 rounded-full bg-emerald-500 border-2 border-white dark:border-zinc-900 flex items-center justify-center text-white text-xs font-bold">+5</div>
                </div>
              </div>

              <div class="space-y-4 font-mono text-sm relative min-h-[300px]">
                <div class="p-4 bg-zinc-50 dark:bg-white/5 rounded-lg border border-zinc-100 dark:border-white/5">
                  <p class="text-emerald-600 dark:text-emerald-400 mb-2">// Connecting to room: 'design-review'</p>
                  <p class="text-zinc-400">Connected in 23ms</p>
                </div>

                <div class="absolute top-1/3 left-1/4 animate-float">
                  <div class="bg-pink-500 px-3 py-1 rounded-full text-white text-xs shadow-lg transform -translate-x-1/2 -translate-y-full mb-2">Sarah</div>
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M5.65376 12.3673H5.46026L5.31717 12.4976L0.500002 16.8829L0.500002 1.19179H11.7841L5.65376 6.8829L5.65376 12.3673Z" fill="#EC4899" stroke="white" stroke-width="2"/></svg>
                </div>

                <div class="absolute bottom-1/3 right-1/4 animate-float-delayed">
                   <div class="bg-emerald-500 px-3 py-1 rounded-full text-white text-xs shadow-lg transform -translate-x-1/2 -translate-y-full mb-2">Mike</div>
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none"><path d="M5.65376 12.3673H5.46026L5.31717 12.4976L0.500002 16.8829L0.500002 1.19179H11.7841L5.65376 6.8829L5.65376 12.3673Z" fill="#10B981" stroke="white" stroke-width="2"/></svg>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Features Section (Bento Grid) -->
      <section id="features" class="py-32 px-6 max-w-7xl mx-auto">
        <div class="text-center max-w-2xl mx-auto mb-20">
          <span class="text-sm font-semibold tracking-widest text-emerald-500 uppercase mb-4 block">Features</span>
          <h2 class="text-4xl md:text-5xl font-bold mb-6 text-zinc-900 dark:text-white">Everything you need for <br/> real-time apps</h2>
          <p class="text-lg text-zinc-600 dark:text-zinc-400">Battle-tested primitives that scale from prototype to production.</p>
        </div>

        <div class="grid md:grid-cols-3 gap-6">
          <!-- Presence (Large Card) -->
          <div class="md:col-span-2 bg-zinc-50 dark:bg-zinc-900/50 border border-zinc-200 dark:border-white/10 rounded-3xl p-8 hover:border-emerald-500/30 transition-colors group relative overflow-hidden">
            <div class="absolute inset-0 bg-gradient-to-br from-emerald-500/5 to-purple-500/5 opacity-0 group-hover:opacity-100 transition-opacity"></div>
            <div class="relative z-10">
              <div class="w-12 h-12 bg-white dark:bg-white/10 rounded-2xl flex items-center justify-center mb-6 text-emerald-500 shadow-lg shadow-emerald-500/10">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="8" stroke-dasharray="4 2"/></svg>
              </div>
              <h3 class="text-2xl font-bold mb-3 text-zinc-900 dark:text-white">Presence Tracking</h3>
              <p class="text-zinc-600 dark:text-zinc-400 mb-8 max-w-md">
                Know who's online, what they're viewing, and what they're doing. CRDT-based sync ensures consistency across distributed nodes.
              </p>
              <div class="flex gap-8">
                <div>
                  <span class="text-2xl font-bold text-zinc-900 dark:text-white">&lt;50ms</span>
                  <span class="text-xs text-zinc-500 uppercase tracking-wider block mt-1">Latency</span>
                </div>
                <div>
                  <span class="text-2xl font-bold text-zinc-900 dark:text-white">Unlimited</span>
                  <span class="text-xs text-zinc-500 uppercase tracking-wider block mt-1">Users</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Cursors (Tall Card) -->
          <div class="bg-zinc-900 dark:bg-white/5 border border-zinc-200 dark:border-white/10 rounded-3xl p-8 hover:border-emerald-500/30 transition-colors relative overflow-hidden group">
            <div class="absolute inset-0 bg-gradient-to-b from-transparent to-black/20 dark:to-black/50 pointer-events-none"></div>
            <div class="relative z-10 h-full flex flex-col">
              <div class="w-12 h-12 bg-zinc-800 dark:bg-white/10 rounded-2xl flex items-center justify-center mb-6 text-emerald-500">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 3l7.07 16.97 2.51-7.39 7.39-2.51L3 3z"/></svg>
              </div>
              <h3 class="text-2xl font-bold mb-3 text-white">Live Cursors</h3>
              <p class="text-zinc-400 mb-6 flex-grow">
                See where everyone is working with smooth, labeled cursors. Automatic throttling.
              </p>
              <div class="mt-auto pt-6 border-t border-white/10">
                <span class="text-emerald-400 font-mono text-sm">60fps Smoothing</span>
              </div>
            </div>
          </div>

          <!-- Comments -->
          <div class="bg-white dark:bg-zinc-900/50 border border-zinc-200 dark:border-white/10 rounded-3xl p-8 hover:border-emerald-500/30 transition-colors">
            <div class="w-12 h-12 bg-zinc-100 dark:bg-white/10 rounded-2xl flex items-center justify-center mb-6 text-emerald-500">
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
            </div>
            <h3 class="text-xl font-bold mb-3 text-zinc-900 dark:text-white">Contextual Comments</h3>
            <p class="text-zinc-600 dark:text-zinc-400 text-sm">
              Pin discussions to any element. Support for replies, mentions, and reactions.
            </p>
          </div>

          <!-- Notifications (Wide) -->
          <div class="md:col-span-2 bg-gradient-to-br from-emerald-900 via-zinc-900 to-zinc-900 dark:from-emerald-950/30 dark:to-zinc-900/50 border border-zinc-200 dark:border-white/10 rounded-3xl p-8 hover:border-emerald-500/30 transition-colors relative overflow-hidden">
             <div class="relative z-10 flex flex-col md:flex-row md:items-center gap-6">
               <div class="flex-1">
                 <div class="w-12 h-12 bg-white/10 rounded-2xl flex items-center justify-center mb-6 text-emerald-400">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
                </div>
                <h3 class="text-2xl font-bold mb-3 text-white">Real-time Notifications</h3>
                <p class="text-zinc-400 max-w-sm">
                  Activity feeds, @mentions, and smart batching included. Instant delivery via WebSockets.
                </p>
               </div>

               <div class="w-full md:w-1/3 bg-black/20 rounded-xl p-4 backdrop-blur-sm border border-white/5">
                 <div class="flex items-start gap-3 mb-3">
                   <div class="w-8 h-8 rounded-full bg-purple-500 flex items-center justify-center text-xs font-bold text-white">JD</div>
                   <div>
                     <p class="text-xs text-zinc-300"><span class="text-white font-semibold">John Doe</span> mentioned you</p>
                     <p class="text-[10px] text-zinc-500 mt-1">2 mins ago</p>
                   </div>
                 </div>
                 <div class="flex items-start gap-3">
                    <div class="w-8 h-8 rounded-full bg-emerald-500 flex items-center justify-center text-xs font-bold text-white">S</div>
                   <div>
                     <p class="text-xs text-zinc-300"><span class="text-white font-semibold">System</span> alert</p>
                     <p class="text-[10px] text-zinc-500 mt-1">Just now</p>
                   </div>
                 </div>
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
