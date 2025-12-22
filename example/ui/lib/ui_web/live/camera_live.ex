defmodule UiWeb.CameraLive do
  use UiWeb, :live_view

  @pubsub_topic "camera"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      UiWeb.Endpoint.subscribe(@pubsub_topic)
    end

    {:ok,
     assign(socket,
       camera_data: nil,
       tpu_elapsed: nil,
       elapsed_since_last_frame: nil,
       frame: nil,
       frame_num: nil,
       results: nil,
       last_results: nil
     )}
  end

  def handle_info(%{topic: @pubsub_topic, payload: data}, socket) do
    update_assigns(socket, data)
  end

  # Handle direct payload (when broadcast sends the map directly)
  # Only match maps that look like camera data (have "frame" key)
  def handle_info(%{"frame" => _} = data, socket) do
    update_assigns(socket, data)
  end

  # Ignore other messages
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp update_assigns(socket, data) do
    current_results = Map.get(data, "results")
    last_results = if current_results != nil and current_results != [], do: current_results, else: socket.assigns.last_results

    {:noreply,
     assign(socket,
       camera_data: data,
       tpu_elapsed: Map.get(data, "tpu_elapsed"),
       elapsed_since_last_frame: Map.get(data, "elapsed_since_last_frame"),
       frame: Map.get(data, "frame"),
       frame_num: Map.get(data, "frame_num"),
       results: current_results,
       last_results: last_results
     )}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <h1 class="text-2xl font-bold">Camera Data</h1>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="space-y-4">
            <div class="bg-gray-100 p-4 rounded-lg">
              <h2 class="font-semibold mb-2">Frame Information</h2>
              <div class="space-y-2 text-sm">
                <div>
                  <span class="font-medium">Frame Number:</span>
                  <span class="ml-2"><%= @frame_num || "N/A" %></span>
                </div>
                <div>
                  <span class="font-medium">TPU Elapsed:</span>
                  <span class="ml-2"><%= @tpu_elapsed || "N/A" %> ms</span>
                </div>
                <div>
                  <span class="font-medium">Elapsed Since Last Frame:</span>
                  <span class="ml-2"><%= @elapsed_since_last_frame || "N/A" %> ms</span>
                </div>
              </div>
            </div>
          </div>

          <div class="space-y-4">
            <div class="bg-gray-100 p-4 rounded-lg">
              <h2 class="font-semibold mb-2">Frame</h2>
              <%= if @frame do %>
                <img
                  src={"data:image/jpeg;base64,#{@frame}"}
                  alt="Camera Frame"
                  class="max-w-full h-auto rounded border"
                />
              <% else %>
                <div class="text-gray-500 text-center py-8">No frame data available</div>
              <% end %>
            </div>

            <div class="bg-gray-100 p-4 rounded-lg">
              <h2 class="font-semibold mb-2">Last Results (JSON)</h2>
              <pre class="text-xs overflow-auto max-h-96 bg-white p-2 rounded border"><%= if @last_results, do: Jason.encode!(@last_results, pretty: true), else: "No data" %></pre>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
