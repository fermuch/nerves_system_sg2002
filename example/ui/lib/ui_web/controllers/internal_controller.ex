defmodule UiWeb.InternalController do
  use UiWeb, :controller

  require Logger

  def camera(conn, params) do
    # Update GenServer state as fast as possible
    Ui.CameraState.update(params)

    conn
    |> put_status(:ok)
    |> json(%{status: "ok"})
  end
end
