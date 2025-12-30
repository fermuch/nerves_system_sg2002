defmodule UiWeb.CameraLive do
  use UiWeb, :live_view

  @update_interval 100
  @led_path "/sys/class/leds/white/brightness"

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
       last_results: nil,
       temperature: nil,
       led_on: read_led_state()
     )}
  end

  # Timer message to query GenServer and update client (excluding frame)
  def handle_info(:fetch_update, socket) do
    state = Ui.CameraState.get()
    temperature = read_temperature()
    schedule_update()

    {:noreply,
     assign(socket,
       tpu_elapsed: state.tpu_elapsed,
       elapsed_since_last_frame: state.elapsed_since_last_frame,
       frame_num: state.frame_num,
       results: state.results,
       last_results: state.last_results,
       temperature: temperature
     )}
  end

  # Ignore other messages
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_led", _params, socket) do
    new_state = !socket.assigns.led_on
    write_led_state(new_state)
    {:noreply, assign(socket, led_on: new_state)}
  end

  defp schedule_update do
    Process.send_after(self(), :fetch_update, @update_interval)
  end

  defp read_temperature do
    case File.read("/sys/class/thermal/thermal_zone0/temp") do
      {:ok, content} ->
        content
        |> String.trim()
        |> String.to_integer()
        |> Kernel./(1000)
        |> Float.round(1)

      {:error, _} ->
        nil
    end
  end

  defp read_led_state do
    case File.read(@led_path) do
      {:ok, content} ->
        content |> String.trim() |> String.to_integer() > 0

      {:error, _} ->
        false
    end
  end

  defp write_led_state(on?) do
    value = if on?, do: "1", else: "0"
    File.write(@led_path, value)
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
                <div>
                  <span class="font-medium">Temperature:</span>
                  <span class="ml-2">
                    <%= if @temperature, do: "#{:erlang.float_to_binary(@temperature, decimals: 1)}°C", else: "N/A" %>
                  </span>
                </div>
              </div>
            </div>

            <div class="bg-gray-100 p-4 rounded-lg">
              <h2 class="font-semibold mb-2">LED Control</h2>
              <button
                id="led-toggle-btn"
                phx-click="toggle_led"
                class={[
                  "px-4 py-2 rounded font-medium text-white transition-colors",
                  if(@led_on, do: "bg-green-600 hover:bg-green-700", else: "bg-gray-500 hover:bg-gray-600")
                ]}
              >
                <%= if @led_on, do: "LED ON", else: "LED OFF" %>
              </button>
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
