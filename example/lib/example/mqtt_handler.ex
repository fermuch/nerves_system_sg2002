defmodule Example.MqttHandler do
  @moduledoc false

  @behaviour Tortoise.Handler

  require Logger

  @cam_enabled_levels ["sscma", "v0", "recamera", "node", "out", "cam1"]
  @stream_enabled_levels ["sscma", "v0", "recamera", "node", "out", "stream1"]

  @expected_enabled_payload ~S({"code":0,"data":true,"name":"enabled","type":0})

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
  def handle_message(@cam_enabled_levels, payload, state) when payload == @expected_enabled_payload do
    Logger.info("Camera enabled acknowledgment received")
    {:ok, state}
  end

  def handle_message(@stream_enabled_levels, payload, state) when payload == @expected_enabled_payload do
    Logger.info("Stream enabled acknowledgment received; setup complete")
    {:ok, state}
  end

  def handle_message(["sscma", "v0", "recamera", "node", "out", extra], payload, state) do
    Logger.info("Received general message (#{extra}): #{inspect(payload)}")
    {:ok, state}
  end

  # def handle_message(_topic_levels, _payload, state) do
  #   {:ok, state}
  # end

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
