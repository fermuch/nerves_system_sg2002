defmodule Ui.CameraState do
  @moduledoc """
  GenServer that stores the latest camera state.
  Updated as fast as possible from HTTP requests.
  """
  use GenServer

  @name __MODULE__

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: @name)
  end

  @doc """
  Update the camera state with new data.
  This is called from HTTP requests and should be as fast as possible.
  """
  def update(data) do
    GenServer.cast(@name, {:update, data})
  end

  @doc """
  Get the current camera state.
  This is called periodically from LiveView.
  """
  def get do
    GenServer.call(@name, :get)
  end

  @doc """
  Get the current frame (base64 encoded JPEG).
  Used for MJPEG streaming.
  """
  def get_frame do
    GenServer.call(@name, :get_frame)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %{
      camera_data: nil,
      tpu_elapsed: nil,
      elapsed_since_last_frame: nil,
      frame: nil,
      frame_num: nil,
      results: nil,
      last_results: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:update, data}, state) do
    current_results = Map.get(data, "results")
    last_results =
      if current_results != nil and current_results != [] do
        current_results
      else
        state.last_results
      end

    new_state = %{
      camera_data: data,
      tpu_elapsed: Map.get(data, "tpu_elapsed"),
      elapsed_since_last_frame: Map.get(data, "elapsed_since_last_frame"),
      frame: Map.get(data, "frame"),
      frame_num: Map.get(data, "frame_num"),
      results: current_results,
      last_results: last_results
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_frame, _from, state) do
    {:reply, state.frame, state}
  end
end
