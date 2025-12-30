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
    <style>
      .camera-container {
        display: flex;
        flex-direction: column;
        gap: 24px;
      }
      .camera-title {
        font-size: 24px;
        font-weight: bold;
        margin: 0;
      }
      .camera-grid {
        display: grid;
        grid-template-columns: 1fr;
        gap: 24px;
      }
      @media (min-width: 768px) {
        .camera-grid {
          grid-template-columns: 1fr 1fr;
        }
      }
      .camera-section {
        display: flex;
        flex-direction: column;
        gap: 16px;
      }
      .camera-card {
        background-color: #f3f4f6;
        padding: 16px;
        border-radius: 8px;
      }
      .camera-card h2 {
        font-weight: 600;
        margin: 0 0 8px 0;
        font-size: 18px;
      }
      .info-list {
        display: flex;
        flex-direction: column;
        gap: 8px;
        font-size: 14px;
      }
      .info-item {
        display: flex;
      }
      .info-label {
        font-weight: 500;
      }
      .info-value {
        margin-left: 8px;
      }
      .led-button {
        padding: 12px 24px;
        border-radius: 6px;
        font-weight: 500;
        color: white;
        border: none;
        cursor: pointer;
        font-size: 16px;
        transition: background-color 0.2s ease, transform 0.1s ease;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
      }
      .led-button:hover {
        transform: translateY(-1px);
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.15);
      }
      .led-button:active {
        transform: translateY(0);
      }
      .led-button-on {
        background-color: #16a34a;
      }
      .led-button-on:hover {
        background-color: #15803d;
      }
      .led-button-off {
        background-color: #6b7280;
      }
      .led-button-off:hover {
        background-color: #4b5563;
      }
      .camera-frame {
        max-width: 100%;
        height: auto;
        border-radius: 4px;
        border: 1px solid #d1d5db;
      }
      .json-display {
        font-size: 12px;
        overflow: auto;
        max-height: 384px;
        background-color: white;
        padding: 8px;
        border-radius: 4px;
        border: 1px solid #d1d5db;
        font-family: 'Courier New', monospace;
      }
    </style>
    <Layouts.app flash={@flash}>
      <div class="camera-container">
        <h1 class="camera-title">Camera Data</h1>

        <div class="camera-grid">
          <div class="camera-section">
            <div class="camera-card">
              <h2>Frame Information</h2>
              <div class="info-list">
                <div class="info-item">
                  <span class="info-label">Frame Number:</span>
                  <span class="info-value"><%= @frame_num || "N/A" %></span>
                </div>
                <div class="info-item">
                  <span class="info-label">TPU Elapsed:</span>
                  <span class="info-value"><%= @tpu_elapsed || "N/A" %> ms</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Elapsed Since Last Frame:</span>
                  <span class="info-value"><%= @elapsed_since_last_frame || "N/A" %> ms</span>
                </div>
                <div class="info-item">
                  <span class="info-label">Temperature:</span>
                  <span class="info-value">
                    <%= if @temperature, do: "#{:erlang.float_to_binary(@temperature, decimals: 1)}°C", else: "N/A" %>
                  </span>
                </div>
              </div>
            </div>

            <div class="camera-card">
              <h2>LED Control</h2>
              <button
                id="led-toggle-btn"
                phx-click="toggle_led"
                class={[
                  "led-button",
                  if(@led_on, do: "led-button-on", else: "led-button-off")
                ]}
              >
                <%= if @led_on, do: "LED ON", else: "LED OFF" %>
              </button>
            </div>
          </div>

          <div class="camera-section">
            <div class="camera-card">
              <h2>Frame</h2>
              <img
                src={~p"/api/camera/mjpeg"}
                alt="Camera Frame"
                class="camera-frame"
              />
            </div>

            <div class="camera-card">
              <h2>Last Results (JSON)</h2>
              <pre class="json-display"><%= if @last_results, do: Jason.encode!(@last_results, pretty: true), else: "No data" %></pre>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
