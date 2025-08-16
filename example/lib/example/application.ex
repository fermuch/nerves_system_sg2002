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
        # {Example.MqttManager, []},
        # Supervisor.child_spec({MuonTrap.Daemon, ["mosquitto", ["-c", "/etc/mosquitto/mosquitto.conf"]]}, id: :mosquitto_daemon),
        # Supervisor.child_spec({MuonTrap.Daemon, ["sscma-node", ["--start"]]}, id: :sscma_node_daemon),
        # Tortoise.Connection.child_spec(
        #   client_id: "example",
        #   handler: {Example.MqttHandler, [client_id: "example"]},
        #   server: {Tortoise.Transport.Tcp, host: ~c"localhost", port: 1883},
        #   subscriptions: [{"sscma/v0/recamera/node/out/#", 0}]
        # )
      ]
    end
  end
end
