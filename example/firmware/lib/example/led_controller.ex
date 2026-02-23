defmodule Example.LedController do
  @moduledoc """
  GenServer that controls the red LED (GPIO 15) based on person detection.

  - LED turns ON immediately when a person is detected (target=0)
  - LED turns OFF after 5 seconds of no person detection
  - The 5-second delay prevents flickering
  """
  use GenServer

  require Logger

  @name __MODULE__

  # GPIO pin for the red LED (porta 15 = GPIO 15)
  @gpio_pin 15
  # Polling interval to check for person detection (ms)
  @poll_interval 100
  # Delay before turning off LED when no person detected (ms)
  @led_off_delay 200

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    # Open GPIO for output
    case Circuits.GPIO.open(@gpio_pin, :output) do
      {:ok, gpio} ->
        # Initialize LED to OFF
        Circuits.GPIO.write(gpio, 0)

        # Schedule first poll
        schedule_poll()

        state = %{
          gpio: gpio,
          led_on: false,
          off_timer: nil
        }

        Logger.info("LedController started, controlling GPIO #{@gpio_pin}")
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to open GPIO #{@gpio_pin}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info(:poll, state) do
    # Check if person is detected
    person_detected = person_detected?()

    new_state =
      if person_detected do
        # Person detected: cancel any pending off timer and turn LED on
        state = cancel_off_timer(state)
        turn_led_on(state)
      else
        # No person detected: start off timer if LED is on and timer not already running
        maybe_start_off_timer(state)
      end

    # Schedule next poll
    schedule_poll()

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:turn_off_led, state) do
    # Timer expired, turn LED off
    new_state = turn_led_off(%{state | off_timer: nil})
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Clean up: turn off LED and close GPIO
    if state.gpio do
      Circuits.GPIO.write(state.gpio, 0)
      Circuits.GPIO.close(state.gpio)
    end

    :ok
  end

  # Private functions

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  defp person_detected? do
    case Ui.CameraState.get() do
      %{results: results} when is_list(results) and results != [] ->
        Enum.any?(results, fn result ->
          Map.get(result, "target") == 0
        end)

      _ ->
        false
    end
  end

  defp turn_led_on(%{led_on: true} = state), do: state

  defp turn_led_on(state) do
    Circuits.GPIO.write(state.gpio, 1)
    Logger.debug("LED ON - person detected")
    %{state | led_on: true}
  end

  defp turn_led_off(%{led_on: false} = state), do: state

  defp turn_led_off(state) do
    Circuits.GPIO.write(state.gpio, 0)
    Logger.debug("LED OFF - no person for #{@led_off_delay}ms")
    %{state | led_on: false}
  end

  defp cancel_off_timer(%{off_timer: nil} = state), do: state

  defp cancel_off_timer(%{off_timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | off_timer: nil}
  end

  defp maybe_start_off_timer(%{led_on: false} = state), do: state
  defp maybe_start_off_timer(%{off_timer: timer} = state) when timer != nil, do: state

  defp maybe_start_off_timer(state) do
    # LED is on and no timer running, start the off timer
    timer = Process.send_after(self(), :turn_off_led, @led_off_delay)
    %{state | off_timer: timer}
  end
end
