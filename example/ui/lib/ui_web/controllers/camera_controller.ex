defmodule UiWeb.CameraController do
  use UiWeb, :controller

  def show(conn, _params) do
    state = Ui.CameraState.get()

    json(conn, %{
      camera_data: state.camera_data,
      tpu_elapsed: state.tpu_elapsed,
      elapsed_since_last_frame: state.elapsed_since_last_frame,
      frame: state.frame,
      frame_num: state.frame_num,
      results: state.results,
      last_results: state.last_results
    })
  end

  def mjpeg(conn, _params) do
    {Plug.Cowboy.Conn, cowboy_req} = conn.adapter
    :cowboy_req.cast({:set_options, %{ idle_timeout: :infinity }}, cowboy_req)

    conn
    |> put_resp_content_type("multipart/x-mixed-replace; boundary=frame")
    |> put_resp_header("Cache-Control", "no-cache, private")
    |> put_resp_header("Connection", "keep-alive")
    |> send_chunked(200)
    |> stream_mjpeg()
  end

  defp stream_mjpeg(conn) do
    case get_frame_and_send(conn) do
      {:ok, conn} ->
        stream_mjpeg(conn)
      {:error, _reason} ->
        conn
    end
  end

  defp get_frame_and_send(conn) do
    case Ui.CameraState.get_frame() do
      nil ->
        # No frame available, wait a bit and retry
        Process.sleep(5)
        get_frame_and_send(conn)
      frame_base64 ->
        frame_binary = Base.decode64!(frame_base64)
        boundary = "\r\n--frame\r\n"
        headers = "Content-Type: image/jpeg\r\nContent-Length: #{byte_size(frame_binary)}\r\n\r\n"
        chunk = boundary <> headers <> frame_binary

        case Plug.Conn.chunk(conn, chunk) do
          {:ok, conn} -> {:ok, conn}
          error -> error
        end
    end
  end
end
