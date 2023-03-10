defmodule JellyfishWeb.JsonUtils do
  alias Jellyfish.{Component, Peer, Room}

  def get_json(%{} = item) when map_size(item) == 0,  do: %{}
  def get_json([]), do: []

  def get_json(collection) when is_list(collection) do
    Enum.map(collection, &get_json/1)
  end

  def get_json(%Room{} = room) do
    IO.inspect(label: :getting_room_json)

    %{
      id: room.id,
      config: %{"maxPeers" => room.config.max_peers},
      components: get_json(room.components),
      peers: get_json(room.peers)
    }
    |> IO.inspect(label: :new_room_returned)
  end

  def get_json(%Component{} = component) do
    type =
      case component.type do
        HLS -> "hls"
      end

    %{
      id: component.id,
      type: type
    }
  end

  def get_json(%Peer{} = peer) do
    type =
      case peer.type do
        WebRTC -> "webrtc"
      end

    %{
      id: peer.id,
      type: type,
      status: "#{peer.status}"
    }
  end
end
