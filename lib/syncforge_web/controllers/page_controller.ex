defmodule SyncforgeWeb.PageController do
  use SyncforgeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def docs(conn, _params) do
    render(conn, :docs,
      page_title: "SyncForge Docs",
      meta_description:
        "Read the SyncForge documentation for setup, SDK usage, and API integration details."
    )
  end

  def blog(conn, _params) do
    render(conn, :blog,
      page_title: "SyncForge Blog",
      meta_description:
        "Product updates, release notes, and engineering deep dives from the SyncForge team."
    )
  end

  def privacy(conn, _params) do
    render(conn, :privacy,
      page_title: "SyncForge Privacy",
      meta_description:
        "Learn how SyncForge handles customer data, privacy, and security controls."
    )
  end

  def contact(conn, _params) do
    render(conn, :contact,
      page_title: "Contact SyncForge",
      meta_description: "Talk to the SyncForge team about pricing, onboarding, and support."
    )
  end
end
