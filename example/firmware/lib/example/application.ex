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
        # Supervisor.child_spec(
        #   {
        #     MuonTrap.Daemon,
        #     [
        #       "sscma-elixir",
        #       ["--model", "/opt/models/yolo11n_cv181x_int8.cvimodel", "--tpu-delay", "300"],
        #       [logger_fun: {Example.AiDispatcher, :dispatch, []}]
        #     ],
        #   },
        #   id: :sscma_elixir_daemon
        # ),
      ]
    end
  end
end
