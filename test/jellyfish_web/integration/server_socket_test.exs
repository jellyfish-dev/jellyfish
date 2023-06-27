defmodule JellyfishWeb.Integration.ServerSocketTest do
  use JellyfishWeb.ConnCase

  alias __MODULE__.Endpoint

  alias Jellyfish.PeerMessage

  alias Jellyfish.ServerMessage

  alias Jellyfish.ServerMessage.{
    Authenticated,
    AuthRequest,
    PeerConnected,
    PeerDisconnected,
    RoomCrashed,
    RoomsState,
    RoomState,
    RoomStateRequest
  }

  alias JellyfishWeb.{PeerSocket, ServerSocket, WS}

  @port 5907
  @path "ws://127.0.0.1:#{@port}/socket/server/websocket"
  @auth_response %Authenticated{}

  @max_peers 1

  Application.put_env(
    :jellyfish,
    Endpoint,
    https: false,
    http: [port: @port],
    server: true
  )

  defmodule Endpoint do
    use Phoenix.Endpoint, otp_app: :jellyfish

    alias JellyfishWeb.ServerSocket

    socket("/socket/server", ServerSocket,
      websocket: true,
      longpoll: false
    )

    socket("/socket/peer", PeerSocket,
      websocket: true,
      longpoll: false
    )
  end

  setup_all do
    assert {:ok, _pid} = Endpoint.start_link()
    :ok
  end

  test "invalid token" do
    {:ok, ws} = WS.start_link(@path, :server)
    server_api_token = "invalid" <> Application.fetch_env!(:jellyfish, :server_api_token)
    auth_request = auth_request(server_api_token)

    :ok = WS.send_binary_frame(ws, auth_request)
    assert_receive {:disconnected, {:remote, 1000, "invalid token"}}, 1000
  end

  test "invalid first message" do
    {:ok, ws} = WS.start_link(@path, :server)
    msg = ServerMessage.encode(%ServerMessage{content: {:authenticated, %Authenticated{}}})

    :ok = WS.send_binary_frame(ws, msg)
    assert_receive {:disconnected, {:remote, 1000, "invalid auth request"}}, 1000
  end

  test "correct token" do
    create_and_authenticate()
  end

  test "closes on receiving an invalid message from a client" do
    ws = create_and_authenticate()

    :ok =
      WS.send_binary_frame(
        ws,
        ServerMessage.encode(%ServerMessage{content: {:authenticated, %Authenticated{}}})
      )

    assert_receive {:disconnected, {:remote, 1003, "operation not allowed"}}, 1000
  end

  test "responds with room state", %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    ws = create_and_authenticate()
    {room_id, peer_id, _token, conn} = add_room_and_peer(conn, server_api_token)

    msg = %ServerMessage{
      content: {:room_state_request, %RoomStateRequest{content: {:id, room_id}}}
    }

    :ok = WS.send_binary_frame(ws, ServerMessage.encode(msg))

    assert_receive %RoomState{
      id: ^room_id,
      config: %{max_peers: @max_peers},
      components: [],
      peers: [%RoomState.Peer{id: ^peer_id, type: :WEBRTC, status: :DISCONNECTED}]
    }

    conn = delete(conn, ~p"/room/#{room_id}/")
    assert response(conn, :no_content)
  end

  test "responds with all of the room states", %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    ws = create_and_authenticate()
    {room_id, peer_id, _token, conn} = add_room_and_peer(conn, server_api_token)

    msg = %ServerMessage{
      content: {:room_state_request, %RoomStateRequest{content: {:option, :ALL}}}
    }

    :ok = WS.send_binary_frame(ws, ServerMessage.encode(msg))

    assert_receive %RoomsState{
      rooms: [
        %RoomState{
          id: ^room_id,
          config: %{max_peers: @max_peers},
          components: [],
          peers: [%RoomState.Peer{id: ^peer_id, type: :WEBRTC, status: :DISCONNECTED}]
        }
      ]
    }

    conn = delete(conn, ~p"/room/#{room_id}/")
    assert response(conn, :no_content)
  end

  test "sends a message when room crashes", %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    create_and_authenticate()

    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn = post(conn, ~p"/room", maxPeers: 1)
    assert %{"id" => room_id} = json_response(conn, :created)["data"]
    {:ok, room_pid} = Jellyfish.RoomService.find_room(room_id)

    Process.exit(room_pid, :kill)

    assert_receive %RoomCrashed{room_id: ^room_id}
  end

  test "sends a message when peer connects", %{conn: conn} do
    server_api_token = Application.fetch_env!(:jellyfish, :server_api_token)
    create_and_authenticate()

    {room_id, peer_id, peer_token, conn} = add_room_and_peer(conn, server_api_token)

    {:ok, peer_ws} = WS.start_link("ws://127.0.0.1:#{@port}/socket/peer/websocket", :peer)
    auth_request = peer_auth_request(peer_token)
    :ok = WS.send_binary_frame(peer_ws, auth_request)

    assert_receive %PeerConnected{peer_id: ^peer_id, room_id: ^room_id}

    conn = delete(conn, ~p"/room/#{room_id}/")
    assert response(conn, :no_content)

    assert_receive %PeerDisconnected{peer_id: ^peer_id, room_id: ^room_id}
  end

  def create_and_authenticate(token \\ Application.fetch_env!(:jellyfish, :server_api_token)) do
    auth_request = auth_request(token)

    {:ok, ws} = WS.start_link(@path, :server)
    :ok = WS.send_binary_frame(ws, auth_request)
    assert_receive @auth_response, 1000

    ws
  end

  defp add_room_and_peer(conn, server_api_token) do
    conn = put_req_header(conn, "authorization", "Bearer " <> server_api_token)

    conn = post(conn, ~p"/room", maxPeers: @max_peers)
    assert %{"id" => room_id} = json_response(conn, :created)["data"]

    conn = post(conn, ~p"/room/#{room_id}/peer", type: "webrtc")

    assert %{"token" => peer_token, "peer" => %{"id" => peer_id}} =
             json_response(conn, :created)["data"]

    {room_id, peer_id, peer_token, conn}
  end

  defp auth_request(token) do
    ServerMessage.encode(%ServerMessage{content: {:auth_request, %AuthRequest{token: token}}})
  end

  defp peer_auth_request(token) do
    PeerMessage.encode(%PeerMessage{
      content: {:auth_request, %PeerMessage.AuthRequest{token: token}}
    })
  end
end
