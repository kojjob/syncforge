defmodule SyncforgeWeb.LandingLive do
  @moduledoc """
  Landing page for SyncForge - Real-Time Collaboration Infrastructure.

  Features Apple-inspired minimalist design with dark/light mode support,
  animated presence indicators, and responsive layout.
  """

  use SyncforgeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
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
    <span class="comment">// Initialize SyncForge and join a room</span>
    <span class="keyword">import</span> { SyncForge } <span class="keyword">from</span> <span class="string">'@syncforge/sdk'</span>

    <span class="keyword">const</span> client = <span class="keyword">new</span> <span class="function">SyncForge</span>({
      apiKey: <span class="string">'your-api-key'</span>
    })

    <span class="keyword">const</span> room = client.<span class="function">joinRoom</span>(<span class="string">'my-room'</span>, {
      user: { name: <span class="string">'John'</span>, avatar: <span class="string">'...'</span> }
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
          name: cursor.user.name
        })
      })
    })

    <span class="comment">// Update your cursor position</span>
    document.<span class="function">addEventListener</span>(<span class="string">'mousemove'</span>, (e) => {
      room.<span class="function">updateCursor</span>({ x: e.clientX, y: e.clientY })
    })
    """
  end

  defp code_example("comments") do
    """
    <span class="comment">// Add threaded comments to any element</span>
    <span class="keyword">const</span> thread = room.<span class="function">createThread</span>({
      anchorId: <span class="string">'element-123'</span>,
      position: { x: 100, y: 200 }
    })

    <span class="keyword">await</span> thread.<span class="function">addComment</span>({
      body: <span class="string">'This needs more contrast'</span>
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
    <div
      id="landing-page"
      class="landing-page"
      data-theme={@theme}
      phx-hook="ThemeToggle"
    >
      <!-- Styles -->
      <style>
        /* Import fonts */
        @import url('https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&display=swap');

        /* CSS Variables */
        :root {
          --font-display: 'Instrument Serif', Georgia, serif;
          --font-body: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
          --font-mono: ui-monospace, 'SF Mono', Monaco, monospace;

          /* Light theme (default) */
          --bg-primary: #FAFAF9;
          --bg-secondary: #F5F5F4;
          --bg-elevated: #FFFFFF;
          --text-primary: #1C1917;
          --text-secondary: #57534E;
          --text-tertiary: #A8A29E;
          --border: #E7E5E4;
          --border-subtle: #F5F5F4;
          --accent: #00D4AA;
          --accent-hover: #00B894;
          --accent-soft: rgba(0, 212, 170, 0.1);
          --cta: #7C3AED;
          --cta-hover: #6D28D9;
          --shadow-sm: 0 1px 2px rgba(0,0,0,0.04);
          --shadow-md: 0 4px 12px rgba(0,0,0,0.06);
          --shadow-lg: 0 12px 40px rgba(0,0,0,0.08);
        }

        [data-theme="dark"],
        [data-theme="system"]:has(@media (prefers-color-scheme: dark)) {
          --bg-primary: #0A0A0B;
          --bg-secondary: #141416;
          --bg-elevated: #1C1C1F;
          --text-primary: #FAFAF9;
          --text-secondary: #A1A1AA;
          --text-tertiary: #71717A;
          --border: #27272A;
          --border-subtle: #1C1C1F;
          --accent: #00D4AA;
          --accent-hover: #00E6B8;
          --accent-soft: rgba(0, 212, 170, 0.15);
          --cta: #A78BFA;
          --cta-hover: #C4B5FD;
          --shadow-sm: 0 1px 2px rgba(0,0,0,0.2);
          --shadow-md: 0 4px 12px rgba(0,0,0,0.3);
          --shadow-lg: 0 12px 40px rgba(0,0,0,0.4);
        }

        @media (prefers-color-scheme: dark) {
          [data-theme="system"] {
            --bg-primary: #0A0A0B;
            --bg-secondary: #141416;
            --bg-elevated: #1C1C1F;
            --text-primary: #FAFAF9;
            --text-secondary: #A1A1AA;
            --text-tertiary: #71717A;
            --border: #27272A;
            --border-subtle: #1C1C1F;
            --accent: #00D4AA;
            --accent-hover: #00E6B8;
            --accent-soft: rgba(0, 212, 170, 0.15);
            --cta: #A78BFA;
            --cta-hover: #C4B5FD;
            --shadow-sm: 0 1px 2px rgba(0,0,0,0.2);
            --shadow-md: 0 4px 12px rgba(0,0,0,0.3);
            --shadow-lg: 0 12px 40px rgba(0,0,0,0.4);
          }
        }

        /* Base styles */
        .landing-page {
          background: var(--bg-primary);
          color: var(--text-primary);
          min-height: 100vh;
          transition: background 0.3s ease, color 0.3s ease;
        }

        /* Typography */
        .display-xl {
          font-family: var(--font-display);
          font-size: clamp(2.5rem, 8vw, 5rem);
          font-weight: 400;
          line-height: 1.05;
          letter-spacing: -0.02em;
        }

        .display-lg {
          font-family: var(--font-display);
          font-size: clamp(2rem, 5vw, 3.5rem);
          font-weight: 400;
          line-height: 1.1;
          letter-spacing: -0.02em;
        }

        .display-md {
          font-family: var(--font-display);
          font-size: clamp(1.5rem, 3vw, 2rem);
          font-weight: 400;
          line-height: 1.2;
        }

        .body-lg {
          font-family: var(--font-body);
          font-size: 1.125rem;
          line-height: 1.7;
          color: var(--text-secondary);
        }

        .body-md {
          font-family: var(--font-body);
          font-size: 1rem;
          line-height: 1.6;
          color: var(--text-secondary);
        }

        .label {
          font-family: var(--font-body);
          font-size: 0.75rem;
          font-weight: 600;
          letter-spacing: 0.1em;
          text-transform: uppercase;
          color: var(--accent);
        }

        .mono {
          font-family: var(--font-mono);
        }

        /* Navigation */
        .nav {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          z-index: 100;
          background: rgba(var(--bg-primary), 0.8);
          backdrop-filter: blur(20px);
          -webkit-backdrop-filter: blur(20px);
          border-bottom: 1px solid var(--border-subtle);
        }

        .nav-inner {
          max-width: 1200px;
          margin: 0 auto;
          padding: 1rem 1.5rem;
          display: flex;
          align-items: center;
          justify-content: space-between;
        }

        .logo {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          font-family: var(--font-body);
          font-weight: 600;
          font-size: 1.125rem;
          color: var(--text-primary);
          text-decoration: none;
        }

        .logo-mark {
          width: 32px;
          height: 32px;
          background: linear-gradient(135deg, var(--accent) 0%, var(--cta) 100%);
          border-radius: 8px;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .nav-links {
          display: none;
          gap: 2rem;
        }

        @media (min-width: 768px) {
          .nav-links {
            display: flex;
          }
        }

        .nav-link {
          font-family: var(--font-body);
          font-size: 0.875rem;
          color: var(--text-secondary);
          text-decoration: none;
          transition: color 0.2s;
        }

        .nav-link:hover {
          color: var(--text-primary);
        }

        .nav-actions {
          display: flex;
          align-items: center;
          gap: 0.75rem;
        }

        /* Theme Toggle */
        .theme-toggle {
          display: flex;
          align-items: center;
          gap: 0.25rem;
          padding: 0.25rem;
          background: var(--bg-secondary);
          border-radius: 9999px;
          border: 1px solid var(--border);
        }

        .theme-btn {
          padding: 0.375rem;
          border-radius: 9999px;
          background: transparent;
          border: none;
          color: var(--text-tertiary);
          cursor: pointer;
          transition: all 0.2s;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        .theme-btn.active {
          background: var(--bg-elevated);
          color: var(--text-primary);
          box-shadow: var(--shadow-sm);
        }

        .theme-btn:hover:not(.active) {
          color: var(--text-secondary);
        }

        /* Buttons */
        .btn {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          gap: 0.5rem;
          padding: 0.75rem 1.5rem;
          font-family: var(--font-body);
          font-size: 0.875rem;
          font-weight: 500;
          border-radius: 9999px;
          border: none;
          cursor: pointer;
          transition: all 0.2s;
          text-decoration: none;
        }

        .btn-primary {
          background: var(--cta);
          color: white;
        }

        .btn-primary:hover {
          background: var(--cta-hover);
          transform: translateY(-1px);
        }

        .btn-secondary {
          background: var(--bg-elevated);
          color: var(--text-primary);
          border: 1px solid var(--border);
        }

        .btn-secondary:hover {
          background: var(--bg-secondary);
          border-color: var(--text-tertiary);
        }

        .btn-ghost {
          background: transparent;
          color: var(--text-secondary);
          padding: 0.5rem 1rem;
        }

        .btn-ghost:hover {
          color: var(--text-primary);
          background: var(--bg-secondary);
        }

        /* Hero Section */
        .hero {
          padding: 8rem 1.5rem 4rem;
          max-width: 1200px;
          margin: 0 auto;
        }

        .hero-content {
          text-align: center;
          max-width: 800px;
          margin: 0 auto 4rem;
        }

        .hero-badge {
          display: inline-flex;
          align-items: center;
          gap: 0.5rem;
          padding: 0.5rem 1rem;
          background: var(--accent-soft);
          border: 1px solid var(--accent);
          border-radius: 9999px;
          margin-bottom: 2rem;
          animation: fadeInUp 0.6s ease-out;
        }

        .hero-badge-dot {
          width: 8px;
          height: 8px;
          background: var(--accent);
          border-radius: 50%;
          animation: pulse 2s ease-in-out infinite;
        }

        .hero-title {
          margin-bottom: 1.5rem;
          animation: fadeInUp 0.6s ease-out 0.1s both;
        }

        .hero-title em {
          font-style: italic;
          color: var(--accent);
        }

        .hero-subtitle {
          max-width: 560px;
          margin: 0 auto 2.5rem;
          animation: fadeInUp 0.6s ease-out 0.2s both;
        }

        .hero-actions {
          display: flex;
          flex-wrap: wrap;
          gap: 1rem;
          justify-content: center;
          animation: fadeInUp 0.6s ease-out 0.3s both;
        }

        /* Interactive Demo */
        .hero-demo {
          position: relative;
          background: var(--bg-elevated);
          border: 1px solid var(--border);
          border-radius: 16px;
          padding: 2rem;
          box-shadow: var(--shadow-lg);
          overflow: hidden;
          animation: fadeInUp 0.8s ease-out 0.4s both;
        }

        .demo-header {
          display: flex;
          align-items: center;
          justify-content: space-between;
          margin-bottom: 1.5rem;
          padding-bottom: 1rem;
          border-bottom: 1px solid var(--border);
        }

        .demo-title {
          font-family: var(--font-body);
          font-size: 0.875rem;
          font-weight: 500;
          color: var(--text-primary);
        }

        .demo-presence {
          display: flex;
          align-items: center;
        }

        .presence-avatar {
          width: 28px;
          height: 28px;
          border-radius: 50%;
          border: 2px solid var(--bg-elevated);
          margin-left: -8px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 0.625rem;
          font-weight: 600;
          color: white;
        }

        .presence-avatar:first-child {
          margin-left: 0;
        }

        .presence-avatar.online::after {
          content: '';
          position: absolute;
          bottom: 0;
          right: 0;
          width: 8px;
          height: 8px;
          background: #22C55E;
          border: 2px solid var(--bg-elevated);
          border-radius: 50%;
        }

        .demo-content {
          position: relative;
          min-height: 200px;
          background: var(--bg-secondary);
          border-radius: 8px;
          padding: 1.5rem;
        }

        .demo-text {
          font-family: var(--font-mono);
          font-size: 0.875rem;
          color: var(--text-secondary);
          line-height: 1.8;
        }

        .demo-text .highlight {
          background: rgba(124, 58, 237, 0.2);
          border-bottom: 2px solid var(--cta);
          padding: 0.125rem 0;
        }

        /* Animated Cursors */
        .cursor {
          position: absolute;
          pointer-events: none;
          z-index: 10;
        }

        .cursor-pointer {
          width: 0;
          height: 0;
          border-left: 6px solid transparent;
          border-right: 6px solid transparent;
          border-top: 12px solid;
          transform: rotate(-45deg);
        }

        .cursor-label {
          position: absolute;
          top: 10px;
          left: 8px;
          padding: 0.25rem 0.5rem;
          font-size: 0.625rem;
          font-weight: 500;
          color: white;
          border-radius: 4px;
          white-space: nowrap;
        }

        .cursor-1 {
          animation: cursorMove1 8s ease-in-out infinite;
        }

        .cursor-1 .cursor-pointer { border-top-color: #F472B6; }
        .cursor-1 .cursor-label { background: #F472B6; }

        .cursor-2 {
          animation: cursorMove2 10s ease-in-out infinite;
        }

        .cursor-2 .cursor-pointer { border-top-color: #60A5FA; }
        .cursor-2 .cursor-label { background: #60A5FA; }

        .cursor-3 {
          animation: cursorMove3 7s ease-in-out infinite;
        }

        .cursor-3 .cursor-pointer { border-top-color: #34D399; }
        .cursor-3 .cursor-label { background: #34D399; }

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

        /* Typing Indicator */
        .typing-indicator {
          display: inline-flex;
          align-items: center;
          gap: 0.25rem;
          padding: 0.5rem 0.75rem;
          background: var(--bg-elevated);
          border-radius: 9999px;
          margin-top: 1rem;
          border: 1px solid var(--border);
        }

        .typing-dot {
          width: 4px;
          height: 4px;
          background: var(--text-tertiary);
          border-radius: 50%;
          animation: typingBounce 1.4s ease-in-out infinite;
        }

        .typing-dot:nth-child(2) { animation-delay: 0.2s; }
        .typing-dot:nth-child(3) { animation-delay: 0.4s; }

        @keyframes typingBounce {
          0%, 60%, 100% { transform: translateY(0); }
          30% { transform: translateY(-4px); }
        }

        /* Features Section */
        .features {
          padding: 6rem 1.5rem;
          max-width: 1200px;
          margin: 0 auto;
        }

        .section-header {
          text-align: center;
          max-width: 600px;
          margin: 0 auto 4rem;
        }

        .section-header .label {
          margin-bottom: 1rem;
        }

        .section-header .display-lg {
          margin-bottom: 1rem;
        }

        .features-grid {
          display: grid;
          gap: 1.5rem;
        }

        @media (min-width: 768px) {
          .features-grid {
            grid-template-columns: repeat(2, 1fr);
          }
        }

        .feature-card {
          background: var(--bg-elevated);
          border: 1px solid var(--border);
          border-radius: 16px;
          padding: 2rem;
          transition: all 0.3s ease;
        }

        .feature-card:hover {
          border-color: var(--accent);
          transform: translateY(-4px);
          box-shadow: var(--shadow-md);
        }

        .feature-icon {
          width: 48px;
          height: 48px;
          background: var(--accent-soft);
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          margin-bottom: 1.5rem;
          color: var(--accent);
        }

        .feature-title {
          font-family: var(--font-display);
          font-size: 1.25rem;
          margin-bottom: 0.75rem;
          color: var(--text-primary);
        }

        .feature-desc {
          color: var(--text-secondary);
          line-height: 1.6;
          margin-bottom: 1.5rem;
        }

        .feature-metrics {
          display: flex;
          gap: 1.5rem;
          padding-top: 1rem;
          border-top: 1px solid var(--border);
        }

        .metric {
          display: flex;
          flex-direction: column;
          gap: 0.25rem;
        }

        .metric-value {
          font-family: var(--font-mono);
          font-size: 1.25rem;
          font-weight: 600;
          color: var(--accent);
        }

        .metric-label {
          font-size: 0.75rem;
          color: var(--text-tertiary);
        }

        /* Code Section */
        .code-section {
          padding: 6rem 1.5rem;
          background: var(--bg-secondary);
        }

        .code-inner {
          max-width: 1200px;
          margin: 0 auto;
        }

        .code-tabs {
          display: flex;
          gap: 0.5rem;
          margin-bottom: 1.5rem;
          overflow-x: auto;
          padding-bottom: 0.5rem;
        }

        .code-tab {
          padding: 0.5rem 1rem;
          background: transparent;
          border: 1px solid var(--border);
          border-radius: 8px;
          font-family: var(--font-mono);
          font-size: 0.875rem;
          color: var(--text-secondary);
          cursor: pointer;
          transition: all 0.2s;
          white-space: nowrap;
        }

        .code-tab:hover {
          border-color: var(--text-tertiary);
          color: var(--text-primary);
        }

        .code-tab.active {
          background: var(--accent);
          border-color: var(--accent);
          color: white;
        }

        .code-block {
          background: var(--bg-elevated);
          border: 1px solid var(--border);
          border-radius: 12px;
          overflow: hidden;
        }

        .code-header {
          display: flex;
          align-items: center;
          gap: 0.5rem;
          padding: 0.75rem 1rem;
          background: var(--bg-secondary);
          border-bottom: 1px solid var(--border);
        }

        .code-dot {
          width: 12px;
          height: 12px;
          border-radius: 50%;
        }

        .code-dot.red { background: #FF5F57; }
        .code-dot.yellow { background: #FEBC2E; }
        .code-dot.green { background: #28C840; }

        .code-content {
          padding: 1.5rem;
          overflow-x: auto;
        }

        .code-content pre {
          font-family: var(--font-mono);
          font-size: 0.875rem;
          line-height: 1.7;
          color: var(--text-primary);
          margin: 0;
        }

        .code-content .comment { color: var(--text-tertiary); }
        .code-content .keyword { color: var(--cta); }
        .code-content .string { color: var(--accent); }
        .code-content .function { color: #F472B6; }
        .code-content .variable { color: #60A5FA; }

        /* Pricing Section */
        .pricing {
          padding: 6rem 1.5rem;
          max-width: 1200px;
          margin: 0 auto;
        }

        .pricing-grid {
          display: grid;
          gap: 1.5rem;
        }

        @media (min-width: 768px) {
          .pricing-grid {
            grid-template-columns: repeat(2, 1fr);
          }
        }

        @media (min-width: 1024px) {
          .pricing-grid {
            grid-template-columns: repeat(4, 1fr);
          }
        }

        .pricing-card {
          background: var(--bg-elevated);
          border: 1px solid var(--border);
          border-radius: 16px;
          padding: 2rem;
          display: flex;
          flex-direction: column;
          transition: all 0.3s ease;
        }

        .pricing-card:hover {
          transform: translateY(-4px);
          box-shadow: var(--shadow-md);
        }

        .pricing-card.featured {
          border-color: var(--accent);
          position: relative;
        }

        .pricing-card.featured::before {
          content: 'Most Popular';
          position: absolute;
          top: -12px;
          left: 50%;
          transform: translateX(-50%);
          background: var(--accent);
          color: white;
          padding: 0.25rem 0.75rem;
          font-size: 0.75rem;
          font-weight: 600;
          border-radius: 9999px;
        }

        .pricing-name {
          font-family: var(--font-body);
          font-weight: 600;
          font-size: 1rem;
          color: var(--text-primary);
          margin-bottom: 0.5rem;
        }

        .pricing-price {
          display: flex;
          align-items: baseline;
          gap: 0.25rem;
          margin-bottom: 0.5rem;
        }

        .pricing-amount {
          font-family: var(--font-display);
          font-size: 2.5rem;
          color: var(--text-primary);
        }

        .pricing-period {
          font-size: 0.875rem;
          color: var(--text-tertiary);
        }

        .pricing-desc {
          font-size: 0.875rem;
          color: var(--text-secondary);
          margin-bottom: 1.5rem;
          padding-bottom: 1.5rem;
          border-bottom: 1px solid var(--border);
        }

        .pricing-features {
          list-style: none;
          padding: 0;
          margin: 0 0 2rem 0;
          flex-grow: 1;
        }

        .pricing-features li {
          display: flex;
          align-items: flex-start;
          gap: 0.75rem;
          font-size: 0.875rem;
          color: var(--text-secondary);
          margin-bottom: 0.75rem;
        }

        .pricing-features li svg {
          flex-shrink: 0;
          color: var(--accent);
          margin-top: 0.125rem;
        }

        .pricing-card .btn {
          width: 100%;
        }

        /* CTA Section */
        .cta-section {
          padding: 6rem 1.5rem;
          background: var(--bg-secondary);
        }

        .cta-inner {
          max-width: 600px;
          margin: 0 auto;
          text-align: center;
        }

        .cta-title {
          margin-bottom: 1rem;
        }

        .cta-subtitle {
          margin-bottom: 2rem;
        }

        .cta-form {
          display: flex;
          gap: 0.75rem;
          max-width: 400px;
          margin: 0 auto;
        }

        @media (max-width: 480px) {
          .cta-form {
            flex-direction: column;
          }
        }

        .cta-input {
          flex-grow: 1;
          padding: 0.75rem 1rem;
          background: var(--bg-elevated);
          border: 1px solid var(--border);
          border-radius: 9999px;
          font-family: var(--font-body);
          font-size: 0.875rem;
          color: var(--text-primary);
          outline: none;
          transition: border-color 0.2s;
        }

        .cta-input::placeholder {
          color: var(--text-tertiary);
        }

        .cta-input:focus {
          border-color: var(--accent);
        }

        /* Footer */
        .footer {
          padding: 3rem 1.5rem;
          border-top: 1px solid var(--border);
        }

        .footer-inner {
          max-width: 1200px;
          margin: 0 auto;
          display: flex;
          flex-direction: column;
          gap: 2rem;
        }

        @media (min-width: 768px) {
          .footer-inner {
            flex-direction: row;
            justify-content: space-between;
            align-items: center;
          }
        }

        .footer-copy {
          font-size: 0.875rem;
          color: var(--text-tertiary);
        }

        .footer-links {
          display: flex;
          gap: 2rem;
        }

        .footer-link {
          font-size: 0.875rem;
          color: var(--text-secondary);
          text-decoration: none;
          transition: color 0.2s;
        }

        .footer-link:hover {
          color: var(--text-primary);
        }

        /* Animations */
        @keyframes fadeInUp {
          from {
            opacity: 0;
            transform: translateY(20px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        @keyframes pulse {
          0%, 100% { opacity: 1; transform: scale(1); }
          50% { opacity: 0.7; transform: scale(1.1); }
        }
      </style>
      
    <!-- Navigation -->
      <nav class="nav">
        <div class="nav-inner">
          <a href="/" class="logo">
            <div class="logo-mark">
              <svg
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="white"
                stroke-width="2.5"
              >
                <path d="M12 2L2 7l10 5 10-5-10-5z" />
                <path d="M2 17l10 5 10-5" />
                <path d="M2 12l10 5 10-5" />
              </svg>
            </div>
            SyncForge
          </a>

          <div class="nav-links">
            <a href="#features" class="nav-link">Features</a>
            <a href="#developers" class="nav-link">Developers</a>
            <a href="#pricing" class="nav-link">Pricing</a>
            <a href="/docs" class="nav-link">Docs</a>
          </div>

          <div class="nav-actions">
            <div class="theme-toggle">
              <button
                class={"theme-btn #{if @theme == "light", do: "active", else: ""}"}
                phx-click="toggle_theme"
                phx-value-theme="light"
                title="Light mode"
              >
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <circle cx="12" cy="12" r="5" />
                  <path d="M12 1v2m0 18v2M4.22 4.22l1.42 1.42m12.72 12.72l1.42 1.42M1 12h2m18 0h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
                </svg>
              </button>
              <button
                class={"theme-btn #{if @theme == "system", do: "active", else: ""}"}
                phx-click="toggle_theme"
                phx-value-theme="system"
                title="System preference"
              >
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <rect x="2" y="3" width="20" height="14" rx="2" />
                  <path d="M8 21h8m-4-4v4" />
                </svg>
              </button>
              <button
                class={"theme-btn #{if @theme == "dark", do: "active", else: ""}"}
                phx-click="toggle_theme"
                phx-value-theme="dark"
                title="Dark mode"
              >
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
                </svg>
              </button>
            </div>

            <a href="/login" class="btn btn-ghost">Sign in</a>
            <a href="/signup" class="btn btn-primary">Get started</a>
          </div>
        </div>
      </nav>
      
    <!-- Hero Section -->
      <section class="hero">
        <div class="hero-content">
          <div class="hero-badge">
            <span class="hero-badge-dot"></span>
            <span class="label" style="color: var(--text-primary); letter-spacing: 0.05em;">
              Now in Public Beta
            </span>
          </div>

          <h1 class="display-xl hero-title">
            Collaboration<br /><em>made seamless</em>
          </h1>

          <p class="body-lg hero-subtitle">
            Add real-time presence, live cursors, and collaboration features to your app in minutes. Built on the BEAM for legendary reliability.
          </p>

          <div class="hero-actions">
            <a href="/signup" class="btn btn-primary">
              Start building free
              <svg
                width="16"
                height="16"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path d="M5 12h14m-7-7l7 7-7 7" />
              </svg>
            </a>
            <a href="/docs" class="btn btn-secondary">
              Read the docs
            </a>
          </div>
        </div>
        
    <!-- Interactive Demo -->
        <div class="hero-demo">
          <div class="demo-header">
            <span class="demo-title">design-review.fig</span>
            <div class="demo-presence">
              <div class="presence-avatar" style="background: #F472B6; position: relative;">
                <span>SK</span>
              </div>
              <div class="presence-avatar" style="background: #60A5FA; position: relative;">
                <span>JD</span>
              </div>
              <div class="presence-avatar" style="background: #34D399; position: relative;">
                <span>AM</span>
              </div>
              <div
                class="presence-avatar"
                style="background: var(--bg-secondary); color: var(--text-secondary);"
              >
                +3
              </div>
            </div>
          </div>

          <div class="demo-content">
            <div class="demo-text">
              <p style="margin: 0 0 1rem 0;">// Real-time collaboration in action</p>
              <p style="margin: 0 0 0.5rem 0;">
                The hero section needs more <span class="highlight">visual impact</span>.
              </p>
              <p style="margin: 0 0 0.5rem 0;">Let's add animated presence indicators and</p>
              <p style="margin: 0;">make the CTA buttons more prominent.</p>

              <div class="typing-indicator">
                <div class="typing-dot"></div>
                <div class="typing-dot"></div>
                <div class="typing-dot"></div>
                <span style="font-size: 0.75rem; color: var(--text-tertiary); margin-left: 0.5rem;">
                  Sarah is typing...
                </span>
              </div>
            </div>
            
    <!-- Animated Cursors -->
            <div class="cursor cursor-1">
              <div class="cursor-pointer"></div>
              <div class="cursor-label">Sarah K.</div>
            </div>
            <div class="cursor cursor-2">
              <div class="cursor-pointer"></div>
              <div class="cursor-label">John D.</div>
            </div>
            <div class="cursor cursor-3">
              <div class="cursor-pointer"></div>
              <div class="cursor-label">Alex M.</div>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Features Section -->
      <section id="features" class="features">
        <div class="section-header">
          <span class="label">Features</span>
          <h2 class="display-lg">Everything you need for real-time collaboration</h2>
          <p class="body-md">Battle-tested primitives that scale from prototype to production.</p>
        </div>

        <div class="features-grid">
          <div class="feature-card">
            <div class="feature-icon">
              <svg
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <circle cx="12" cy="12" r="3" />
                <circle cx="12" cy="12" r="8" stroke-dasharray="4 2" />
              </svg>
            </div>
            <h3 class="feature-title">Presence Tracking</h3>
            <p class="feature-desc">
              Know who's online, what they're viewing, and what they're doing. CRDT-based sync ensures consistency across distributed nodes.
            </p>
            <div class="feature-metrics">
              <div class="metric">
                <span class="metric-value">&lt;50ms</span>
                <span class="metric-label">Sync latency</span>
              </div>
              <div class="metric">
                <span class="metric-value">∞</span>
                <span class="metric-label">Concurrent users</span>
              </div>
            </div>
          </div>

          <div class="feature-card">
            <div class="feature-icon">
              <svg
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path d="M3 3l7.07 16.97 2.51-7.39 7.39-2.51L3 3z" />
                <path d="M13 13l6 6" />
              </svg>
            </div>
            <h3 class="feature-title">Live Cursors</h3>
            <p class="feature-desc">
              See where everyone is working with smooth, labeled cursors. Automatic throttling keeps bandwidth efficient.
            </p>
            <div class="feature-metrics">
              <div class="metric">
                <span class="metric-value">&lt;30ms</span>
                <span class="metric-label">Broadcast time</span>
              </div>
              <div class="metric">
                <span class="metric-value">60fps</span>
                <span class="metric-label">Smoothing</span>
              </div>
            </div>
          </div>

          <div class="feature-card">
            <div class="feature-icon">
              <svg
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
              </svg>
            </div>
            <h3 class="feature-title">Threaded Comments</h3>
            <p class="feature-desc">
              Pin discussions to any element. Support for replies, mentions, reactions, and resolution tracking.
            </p>
            <div class="feature-metrics">
              <div class="metric">
                <span class="metric-value">Real-time</span>
                <span class="metric-label">Sync</span>
              </div>
              <div class="metric">
                <span class="metric-value">@mentions</span>
                <span class="metric-label">Built-in</span>
              </div>
            </div>
          </div>

          <div class="feature-card">
            <div class="feature-icon">
              <svg
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
                <path d="M13.73 21a2 2 0 0 1-3.46 0" />
              </svg>
            </div>
            <h3 class="feature-title">Notifications</h3>
            <p class="feature-desc">
              Real-time alerts with customizable delivery. Activity feeds, @mentions, and smart batching included.
            </p>
            <div class="feature-metrics">
              <div class="metric">
                <span class="metric-value">Instant</span>
                <span class="metric-label">Delivery</span>
              </div>
              <div class="metric">
                <span class="metric-value">Webhooks</span>
                <span class="metric-label">Supported</span>
              </div>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Code Section -->
      <section id="developers" class="code-section">
        <div class="code-inner">
          <div class="section-header">
            <span class="label">For Developers</span>
            <h2 class="display-lg">Ship collaboration features in minutes</h2>
            <p class="body-md">Clean APIs, type-safe SDKs, and comprehensive documentation.</p>
          </div>

          <div class="code-tabs">
            <button
              class={"code-tab #{if @active_tab == "presence", do: "active", else: ""}"}
              phx-click="set_tab"
              phx-value-tab="presence"
            >
              Presence
            </button>
            <button
              class={"code-tab #{if @active_tab == "cursors", do: "active", else: ""}"}
              phx-click="set_tab"
              phx-value-tab="cursors"
            >
              Cursors
            </button>
            <button
              class={"code-tab #{if @active_tab == "comments", do: "active", else: ""}"}
              phx-click="set_tab"
              phx-value-tab="comments"
            >
              Comments
            </button>
          </div>

          <div class="code-block">
            <div class="code-header">
              <div class="code-dot red"></div>
              <div class="code-dot yellow"></div>
              <div class="code-dot green"></div>
            </div>
            <div class="code-content">
              <pre><%= raw(code_example(@active_tab)) %></pre>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Pricing Section -->
      <section id="pricing" class="pricing">
        <div class="section-header">
          <span class="label">Pricing</span>
          <h2 class="display-lg">Simple, predictable pricing</h2>
          <p class="body-md">Start free, scale as you grow. No surprise bills.</p>
        </div>

        <div class="pricing-grid">
          <div class="pricing-card">
            <span class="pricing-name">Free</span>
            <div class="pricing-price">
              <span class="pricing-amount">$0</span>
              <span class="pricing-period">/month</span>
            </div>
            <p class="pricing-desc">Perfect for trying things out</p>
            <ul class="pricing-features">
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                100 monthly active users
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                5 rooms
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                Presence & Cursors
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                Community support
              </li>
            </ul>
            <a href="/signup" class="btn btn-secondary">Get started</a>
          </div>

          <div class="pricing-card">
            <span class="pricing-name">Starter</span>
            <div class="pricing-price">
              <span class="pricing-amount">$49</span>
              <span class="pricing-period">/month</span>
            </div>
            <p class="pricing-desc">For small teams getting started</p>
            <ul class="pricing-features">
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                1,000 monthly active users
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                10 rooms
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                Everything in Free
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                Email support
              </li>
            </ul>
            <a href="/signup?plan=starter" class="btn btn-secondary">Start trial</a>
          </div>

          <div class="pricing-card featured">
            <span class="pricing-name">Pro</span>
            <div class="pricing-price">
              <span class="pricing-amount">$199</span>
              <span class="pricing-period">/month</span>
            </div>
            <p class="pricing-desc">For growing products</p>
            <ul class="pricing-features">
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                10,000 monthly active users
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                100 rooms
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                Comments & Notifications
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                Priority support
              </li>
            </ul>
            <a href="/signup?plan=pro" class="btn btn-primary">Start trial</a>
          </div>

          <div class="pricing-card">
            <span class="pricing-name">Business</span>
            <div class="pricing-price">
              <span class="pricing-amount">$499</span>
              <span class="pricing-period">/month</span>
            </div>
            <p class="pricing-desc">For scale and custom needs</p>
            <ul class="pricing-features">
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                50,000 monthly active users
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                Unlimited rooms
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                Voice rooms & Analytics
              </li>
              <li>
                <svg
                  width="16"
                  height="16"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <polyline points="20 6 9 17 4 12" />
                </svg>
                Dedicated support
              </li>
            </ul>
            <a href="/contact" class="btn btn-secondary">Contact sales</a>
          </div>
        </div>
      </section>
      
    <!-- CTA Section -->
      <section class="cta-section">
        <div class="cta-inner">
          <h2 class="display-md cta-title">Ready to build?</h2>
          <p class="body-md cta-subtitle">
            Join hundreds of developers shipping real-time features with SyncForge.
          </p>
          <form class="cta-form" phx-submit="submit_email">
            <input
              type="email"
              name="email"
              class="cta-input"
              placeholder="Enter your email"
              value={@email}
              required
            />
            <button type="submit" class="btn btn-primary">Get early access</button>
          </form>
        </div>
      </section>
      
    <!-- Footer -->
      <footer class="footer">
        <div class="footer-inner">
          <p class="footer-copy">© 2026 SyncForge. Built with Elixir & Phoenix.</p>
          <nav class="footer-links">
            <a href="/docs" class="footer-link">Documentation</a>
            <a href="/blog" class="footer-link">Blog</a>
            <a href="https://github.com/syncforge" class="footer-link">GitHub</a>
            <a href="/privacy" class="footer-link">Privacy</a>
          </nav>
        </div>
      </footer>
    </div>
    """
  end
end
