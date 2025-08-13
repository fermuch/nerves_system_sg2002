defmodule Example.MqttHandler do
  @moduledoc false

  @behaviour Tortoise.Handler

  require Logger

  @impl true
  def init(_args), do: {:ok, nil}

  @impl true
  def connection(:up, state) do
    Logger.info("MQTT connection is up; notifying orchestrator")

    Example.MqttManager.on_connection_up()

    {:ok, state}
  end

  def connection(:terminated, state) do
    Logger.warning("MQTT connection terminated")
    {:ok, state}
  end

  @impl true
  def handle_message(["sscma", "v0", "recamera", "node", "out", "cam1"], payload, state) do
    payload = JSON.decode!(payload)

    case payload["code"] do
      0 ->
        Logger.info("Camera enabled acknowledgment received")
        Example.MqttManager.set_cam_created(payload["data"])
      11 ->
        Logger.info("Camera already exists; skipping")
        Example.MqttManager.set_cam_created(true)
      _ ->
        Logger.error("Camera enabled acknowledgment received with error: #{inspect(payload)}")
    end

    {:ok, state}
  end

  def handle_message(["sscma", "v0", "recamera", "node", "out", "stream1"], payload, state) do
    payload = JSON.decode!(payload)

    case payload["code"] do
      0 ->
        Logger.info("Stream enabled acknowledgment received")
        Example.MqttManager.set_stream_created(payload["data"])
      11 ->
        Logger.info("Stream already exists; skipping")
        Example.MqttManager.set_stream_created(true)
      _ ->
        Logger.error("Stream enabled acknowledgment received with error: #{inspect(payload)}")
    end

    {:ok, state}
  end

  def handle_message(["sscma", "v0", "recamera", "node", "out", extra], payload, state) do
    Logger.info("Received general message (#{extra}): #{inspect(payload)}")
    {:ok, state}
  end

  @impl true
  def subscription(_status, _topic_filter, state) do
    {:ok, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.warning("MQTT handler terminating: #{inspect(reason)}")
    :ok
  end
end
