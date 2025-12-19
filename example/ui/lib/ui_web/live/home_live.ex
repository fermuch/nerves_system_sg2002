defmodule UiWeb.HomeLive do
  use UiWeb, :live_view

  def render(assigns) do
    ~H"""
    <div>
      <%= if Map.has_key?(@frame, "frame") do %>
      <img src={"data:image/jpeg;base64,#{@frame["frame"]}"} />
      <% end %>

      <h1>Current data:</h1>
      <pre>{JSON.encode!(@frame)}</pre>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    UiWeb.Endpoint.subscribe("camera")
    {:ok, assign(socket, :frame, %{})}
  end

  def handle_info(%{topic: "camera", payload: frame}, socket) do
    {:noreply, assign(socket, :frame, frame)}
  end
end
