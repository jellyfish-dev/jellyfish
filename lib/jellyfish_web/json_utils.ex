defmodule JellyfishWeb.JsonUtils do
  @moduledoc false
  # Functions for converting structs to appropriate API responses
  alias Jellyfish.{Component, Peer, Room}

  def get_json(item) do
    %{data: do_get_json(item)}
  end

  defp do_get_json(%{} = item) when map_size(item) == 0, do: %{}
  defp do_get_json([]), do: []

  defp do_get_json(collection) when is_list(collection) do
    Enum.map(collection, &do_get_json/1)
  end

  defp do_get_json(%Room{} = room) do
    %{
      id: room.id,
      config: %{"maxPeers" => room.config.max_peers},
      components: do_get_json(room.components),
      peers: do_get_json(room.peers)
    }
  end

  defp do_get_json(%Component{} = component) do
    type =
      case component.type do
        Component.HLS -> "hls"
      end

    %{
      id: component.id,
      type: type
    }
  end

  defp do_get_json(%Peer{} = peer) do
    type =
      case peer.type do
        Peer.WebRTC -> "webrtc"
      end

    %{
      id: peer.id,
      type: type,
      status: "#{peer.status}"
    }
  end
end
