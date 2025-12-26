defmodule UiWeb.CameraLive do
  use UiWeb, :live_view

  @update_interval 100

  def mount(_params, _session, socket) do
    if connected?(socket) do
      schedule_update()
    end

    {:ok,
     assign(socket,
       tpu_elapsed: nil,
       elapsed_since_last_frame: nil,
       frame_num: nil,
       results: nil,
       last_results: nil
     )}
  end

  # Timer message to query GenServer and update client (excluding frame)
  def handle_info(:fetch_update, socket) do
    state = Ui.CameraState.get()
    schedule_update()

    {:noreply,
     assign(socket,
       tpu_elapsed: state.tpu_elapsed,
       elapsed_since_last_frame: state.elapsed_since_last_frame,
       frame_num: state.frame_num,
       results: state.results,
       last_results: state.last_results
     )}
  end

  # Ignore other messages
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp schedule_update do
    Process.send_after(self(), :fetch_update, @update_interval)
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
              <img
                src={~p"/api/camera/mjpeg"}
                alt="Camera Frame"
                class="max-w-full h-auto rounded border"
              />
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
