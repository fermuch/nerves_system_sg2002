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

    cam_message(payload, state)
  end

  def handle_message(["sscma", "v0", "recamera", "node", "out", "model1"], payload, state) do
    payload = JSON.decode!(payload)

    case payload["code"] do
      0 ->
        Logger.info("Model enabled acknowledgment received")
        Example.MqttManager.set_model_created(payload["data"])
      11 ->
        Logger.info("Model already exists; skipping")
        Example.MqttManager.set_model_created(true)
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

  def cam_message(%{"code" => 11, "data" => "Node already exists: cam1"}, state) do
    Logger.info("Camera already exists; skipping")
    Example.MqttManager.set_cam_created(true)
    {:ok, state}
  end

  def cam_message(%{"code" => 0} = payload, state) when is_map_key(payload, "data") and is_boolean(:erlang.map_get("data", payload)) do
    Logger.info("Camera enabled acknowledgment received")
    Example.MqttManager.set_cam_created(payload["data"])

    {:ok, state}
  end

  def cam_message(%{"code" => 0, "data" => data}, state) do
    Logger.info("Camera preview frame received: #{inspect(Map.keys(data))}")
    {:ok, state}
  end

  def cam_message(payload, state) do
    Logger.error("Unknown camera message: #{inspect(payload)}")
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
