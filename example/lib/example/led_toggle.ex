defmodule Example.LEDToggle do
  use GenServer
  require Logger

  @led_path "/sys/devices/platform/leds/leds/white/brightness"
  @toggle_interval 10_000  # 10 seconds in milliseconds

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    Logger.info("Starting LED toggle service")
    schedule_toggle()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:toggle_led, state) do
    toggle_led_state()
    schedule_toggle()
    {:noreply, state}
  end

  # Private Functions

  defp schedule_toggle do
    Process.send_after(self(), :toggle_led, @toggle_interval)
  end

  defp toggle_led_state do
    case File.read(@led_path) do
      {:ok, content} ->
        current_state = String.trim(content)
        new_state = if current_state == "1", do: "0", else: "1"

        case File.write(@led_path, new_state) do
          :ok ->
            Logger.info("LED toggled: #{current_state} -> #{new_state}")

          {:error, reason} ->
            Logger.error("Failed to write LED state: #{inspect(reason)}")
        end

      {:error, reason} ->
        Logger.error("Failed to read LED state: #{inspect(reason)}")
    end
  end
end
