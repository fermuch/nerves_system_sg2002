defmodule UiWeb.PageController do
  use UiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
