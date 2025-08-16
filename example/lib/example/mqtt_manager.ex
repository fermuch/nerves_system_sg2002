defmodule Example.MqttManager do
  @moduledoc """
  This module is responsible for managing the camera and stream creation.
  """

  use GenServer

  require Logger

  @cam_create_topic "sscma/v0/recamera/node/in/cam1"
  @model_create_topic "sscma/v0/recamera/node/in/model1"
  @stream_create_topic "sscma/v0/recamera/node/in/stream1"

  @cam_create_payload JSON.encode!(%{type: 3, name: "create", data: %{type: "camera", config: %{
    option: "480p",
    preview: false,
    audio: false,
  }}})
  @model_create_payload JSON.encode!(%{type: 3, name: "create", data: %{
    type: "model",
    config: %{
      uri: "/opt/models/yolo11n_cv181x_int8.cvimodel",
      debug: true,
      trace: true
    },
    dependencies: ["cam1"]
  }})
  @stream_create_payload JSON.encode!(%{type: 3, name: "create", data: %{type: "stream", config: %{
    user: "example",
    password: "admin",
    port: 554
  }, dependencies: ["cam1", "model1"]}})

  @check_nodes_interval 5000

  defmodule State do
    defstruct [
      :check_nodes_timer,
      :cam_created,
      :model_created,
      :stream_created,
    ]
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl GenServer
  def init(_args) do
    {:ok, %State{
      check_nodes_timer: nil,
      cam_created: false,
      model_created: false,
      stream_created: false,
    }}
  end

  def on_connection_up() do
    Process.send_after(__MODULE__, :on_connection_up, 1000)
  end

  def set_cam_created(value) when is_boolean(value) do
    GenServer.call(__MODULE__, {:set_cam_created, value})
  end

  def set_model_created(value) when is_boolean(value) do
    GenServer.call(__MODULE__, {:set_model_created, value})
  end

  def set_stream_created(value) when is_boolean(value) do
    GenServer.call(__MODULE__, {:set_stream_created, value})
  end

  @impl GenServer
  def handle_info(:on_connection_up, state) do
    Logger.info("MQTT connection is up; creating camera and stream")
    {:ok, _ref} = Tortoise.publish("example", @cam_create_topic, @cam_create_payload, qos: 1)
    {:ok, _ref} = Tortoise.publish("example", @model_create_topic, @model_create_payload, qos: 1)
    {:ok, _ref} = Tortoise.publish("example", @stream_create_topic, @stream_create_payload, qos: 1)

    if state.check_nodes_timer != nil do
      Process.cancel_timer(state.check_nodes_timer)
    end
    new_state = %{state | check_nodes_timer: Process.send_after(__MODULE__, :check_nodes, @check_nodes_interval)}

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:check_nodes, state) do
    Logger.info("Checking nodes")

    if not state.cam_created do
      Logger.info("Camera not created; creating again")
      {:ok, _ref} = Tortoise.publish("example", @cam_create_topic, @cam_create_payload, qos: 1)
    end

    if not state.model_created do
      Logger.info("Model not created; creating again")
      {:ok, _ref} = Tortoise.publish("example", @model_create_topic, @model_create_payload, qos: 1)
    end

    if not state.stream_created do
      Logger.info("Stream not created; creating again")
      {:ok, _ref} = Tortoise.publish("example", @stream_create_topic, @stream_create_payload, qos: 1)
    end

    new_state = %{state | check_nodes_timer: Process.send_after(__MODULE__, :check_nodes, @check_nodes_interval)}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(_other, state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:set_cam_created, cam_created}, _from, state) do
    {:reply, :ok, %{state | cam_created: cam_created}}
  end

  @impl GenServer
  def handle_call({:set_stream_created, stream_created}, _from, state) do
    {:reply, :ok, %{state | stream_created: stream_created}}
  end
end
