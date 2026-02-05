defmodule SyncforgeWeb.PageController do
  use SyncforgeWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
