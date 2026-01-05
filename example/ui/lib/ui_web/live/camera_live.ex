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
        display: block;
      }
      #camera-canvas {
        background-color: #000;
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
              <div style="position: relative; display: inline-block;">
                <canvas id="camera-canvas" class="camera-frame" width="426" height="240"></canvas>
                <img id="camera-source" style="display: none;" width="426" height="240" />
                <div id="detection-data" data-results={if @results, do: Jason.encode!(@results), else: "[]"} style="display: none;"></div>
              </div>
            </div>

            <div class="camera-card">
              <h2>Last Results (JSON)</h2>
              <pre class="json-display"><%= if @last_results, do: Jason.encode!(@last_results, pretty: true), else: "No data" %></pre>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    <script phx-track-static src={~p"/assets/vendor/mjpeg.js"}></script>
    <script>
      (function() {
        function getDetections() {
          const detectionData = document.getElementById('detection-data');
          if (!detectionData) {
            return [];
          }
          try {
            const results = JSON.parse(detectionData.getAttribute('data-results') || '[]');
            return Array.isArray(results) ? results : [];
          } catch (e) {
            console.error('Error parsing detection data:', e);
            return [];
          }
        }

        let drawing = false;
        function initMJPEG() {
          if (typeof MJPEG === 'undefined') {
            // Wait for mjpeg.js to load
            setTimeout(initMJPEG, 100);
            return;
          }

          const sourceImg = document.getElementById('camera-source');
          const canvas = document.getElementById('camera-canvas');
          if (!sourceImg || !canvas) {
            console.error('Camera elements not found');
            return;
          }

          const ctx = canvas.getContext('2d');
          let canvasWidth = 0;
          let canvasHeight = 0;

          // Function to draw detection boxes on canvas
          function drawDetections() {
            const detections = getDetections();
            if (!detections || detections.length === 0) {
              return;
            }

            // Draw each detection box
            detections.forEach(function(detection) {
              // Format: {abs: {x1, y1, x2, y2}, target: 0 (person), score: ...}
              if (!detection.abs) {
                return;
              }

              const abs = detection.abs;
              const x = Math.round(abs.x1 || 0);
              const y = Math.round(abs.y1 || 0);
              const width = Math.round((abs.x2 || 0) - x);
              const height = Math.round((abs.y2 || 0) - y);

              if (width <= 0 || height <= 0) {
                return;
              }

              // Draw bounding box
              ctx.strokeStyle = '#00ff00';
              ctx.lineWidth = 2;
              ctx.strokeRect(x, y, width, height);

              if (detection.target === 0 && detection.score !== undefined) {
                const label = 'Person';
                const score = (detection.score * 100).toFixed(1) + '%';
                const labelText = `${label} ${score}`;

                ctx.fillStyle = '#00ff00';
                ctx.font = '16px Arial';
                ctx.fillText(labelText, x, Math.max(y - 5, 15));
              }
            });
          }

          // Function to update canvas with image and detections
          function updateCanvas() {
            if (drawing) {
              return;
            }
            drawing = true;
            if (!sourceImg.complete) {
              console.debug('[Canvas] Image not complete yet');
              return;
            }

            if (sourceImg.naturalWidth === 0 || sourceImg.naturalHeight === 0) {
              console.debug('[Canvas] Image has no dimensions yet', {
                naturalWidth: sourceImg.naturalWidth,
                naturalHeight: sourceImg.naturalHeight,
                src: sourceImg.src ? 'set' : 'not set'
              });
              return;
            }

            // Clear canvas
            ctx.clearRect(0, 0, canvasWidth, canvasHeight);

            // Draw image on canvas
            try {
              ctx.drawImage(sourceImg, 0, 0);
              console.debug('[Canvas] Image drawn to canvas');
            } catch (e) {
              console.error('[Canvas] Error drawing image:', e);
              return;
            }

            // Draw detection boxes on top
            drawDetections();
            drawing = false;
          }

          const streamUrl = new URL("/api/camera/mjpeg", document.location).href;

          // Create MJPEG player instance
          const player = new MJPEG.Player(
            sourceImg,
            streamUrl,
            null, // username
            null, // password
            {
              onStart: function() {
                console.info('[MJPEG] Stream started');
              },
              onStop: function() {
                console.info('[MJPEG] Stream stopped');
              },
              onError: function(status, payload) {
                console.error('[MJPEG] Error:', status, payload);
              },
              onFrame: function(frame) {},
              onLoad: function(event) {
                updateCanvas();
              }
            }
          );

          sourceImg.addEventListener('error', function(e) {
            console.error('[Image] Error loading image:', e);
          });

          // Start the stream
          player.start();

          // Cleanup on page unload
          window.addEventListener('beforeunload', function() {
            player.stop();
            if (sourceImg.dataset.prevUrl) {
              URL.revokeObjectURL(sourceImg.dataset.prevUrl);
            }
          });
        }

        // Initialize when DOM is ready
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', initMJPEG);
        } else {
          initMJPEG();
        }
      })();
    </script>
    """
  end
end
