defmodule Example.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Children for all targets
        # Starts a worker by calling: Example.Worker.start_link(arg)
        # {Example.Worker, arg},
      ] ++ target_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def show_children(), do: target_children()

  # List all child processes to be supervised
  if Mix.target() == :host do
    defp target_children() do
      [
        # Children that only run on the host during development or test.
        # In general, prefer using `config/host.exs` for differences.
        #
        # Starts a worker by calling: Host.Worker.start_link(arg)
        # {Host.Worker, arg},
      ]
    end
  else
    defp target_children() do
      [
        Supervisor.child_spec(
          {
            MuonTrap.Daemon,
            [
              # "sscma-elixir",
              # ["--model", "/opt/models/yolo11n_cv181x_int8.cvimodel", "--tpu-delay", "300", "--base64", "0"],
              "/data/run",
              [
                "--model", "/data/model.cvimodel",
                # Detections over 50% confidence are published
                "--threshold", "0.5",
                # Enable receiving base64 encoded images
                "--base64", "1",
                # Publish the detections to the internal camera endpoint
                "--publish-http-to", "http://localhost/internal/camera",
                # We only need http, so we can silence the console output
                "--quiet",
                # Use a smaller resolution for faster streaming over HTTP, since
                # the USB ethernet is slow
                # Internally, the TPU uses a resolution of 640x640
                "--camera-width", "426",
                "--camera-height", "240",
                # Process frames as fast as possible
                "--fps", "40",
              ],
              [
                # logger_fun: {Example.AiDispatcher, :dispatch, []},
              ]
            ],
          },
          id: :sscma_elixir_daemon
        ),
        # LED controller for person detection indication
        Example.LedController
      ]
    end
  end
end
