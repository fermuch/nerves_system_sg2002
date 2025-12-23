defmodule UiWeb.InternalController do
  use UiWeb, :controller

  require Logger

  alias Phoenix.PubSub

  @pubsub_topic "camera"

  def camera(conn, params) do
    PubSub.broadcast(Ui.PubSub, @pubsub_topic, params)

    conn
    |> put_status(:ok)
    |> json(%{status: "ok"})
  end
end
