defmodule Example.AiDispatcher do
  @moduledoc """
  Receives and dispatches AI data to PubSub.
  """

  require Logger
  alias Phoenix.PubSub

  @json_regex ~r/^[^{]*(\{.*\})[^}]*$/
  @pubsub_topic "camera"

  def dispatch(payload) do
    case Regex.run(@json_regex, payload) do
      [_, json_string] ->
        case JSON.decode(json_string) do
          {:ok, parsed_json} ->
            PubSub.broadcast(Ui.PubSub, @pubsub_topic, parsed_json)
            {:ok, parsed_json}
          {:error, error} ->
            Logger.error("Error decoding JSON: #{inspect(error)}")
            {:error, error}
        end

      nil ->
        {:error, "No valid JSON found"}
    end
  end
end
