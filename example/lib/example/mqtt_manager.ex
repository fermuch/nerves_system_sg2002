defmodule Example.MqttManager do
  @moduledoc """
  This module is responsible for managing the camera and stream creation.
  """

  use GenServer

  require Logger

  @cam_create_topic "sscma/v0/recamera/node/in/cam1"
  @stream_create_topic "sscma/v0/recamera/node/in/stream1"

  @cam_create_payload ~S({"type":3,"name":"create","data":{"type":"camera","config":{}}})
  @stream_create_payload ~S({"type":3,"name":"create","data":{"type":"stream","config":{},"dependencies":["cam1"]}})


  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_args) do
    {:ok, nil}
  end

  def on_connection_up() do
    Process.send_after(__MODULE__, :on_connection_up, 5000)
  end

  def handle_info(:on_connection_up, state) do
    Logger.info("MQTT connection is up; creating camera and stream")
    _ = Tortoise.publish("example", @cam_create_topic, @cam_create_payload, qos: 1)
    _ = Tortoise.publish("example", @stream_create_topic, @stream_create_payload, qos: 1)
    {:noreply, state}
  end
end
