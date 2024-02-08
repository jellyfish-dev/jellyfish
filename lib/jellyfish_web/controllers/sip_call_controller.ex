defmodule JellyfishWeb.SIPCallController do
  use JellyfishWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias Jellyfish.Room
  alias Jellyfish.RoomService
  alias JellyfishWeb.ApiSpec
  alias OpenApiSpex.Response

  action_fallback JellyfishWeb.FallbackController

  tags [:sip]

  operation :create,
    operation_id: "dial",
    summary: "Making a call from the SIP component to the provided phone number",
    parameters: [
      room_id: [in: :path, description: "Room ID", type: :string],
      component_id: [in: :path, description: "SIP Component ID", type: :string]
    ],
    request_body: {"Phone Number configuration", "application/json", ApiSpec.Dial},
    responses: [
      created: %Response{description: "Call started"},
      bad_request: ApiSpec.error("Invalid request structure"),
      not_found: ApiSpec.error("Room doesn't exist")
    ]

  operation :delete,
    operation_id: "end_call",
    summary: "Finish call made by SIP component",
    parameters: [
      room_id: [in: :path, description: "Room ID", type: :string],
      component_id: [in: :path, description: "SIP Component ID", type: :string]
    ],
    responses: [
      created: %Response{description: "Call ended"},
      bad_request: ApiSpec.error("Invalid request structure"),
      not_found: ApiSpec.error("Room doesn't exist")
    ]

  def create(conn, %{"room_id" => room_id, "component_id" => component_id} = params) do
    with {:ok, phone_number} <- Map.fetch(params, "phoneNumber"),
         {:ok, _room_pid} <- RoomService.find_room(room_id),
         :ok <- Room.dial(room_id, component_id, phone_number) do
      send_resp(conn, :created, "Successfully subscribed for tracks")
    else
      :error ->
        {:error, :bad_request, "Invalid request body structure"}

      {:error, :room_not_found} ->
        {:error, :not_found, "Room #{room_id} does not exist"}

      {:error, :component_not_exist} ->
        {:error, :bad_request, "Component with #{component_id} does not exist"}

      {:error, :bad_component_type} ->
        {:error, :bad_request, "Component with #{component_id} is not SIP component"}
    end
  end

  def delete(conn, %{"room_id" => room_id, "component_id" => component_id} = params) do
    with {:ok, origins} <- Map.fetch(params, "origins"),
         {:ok, _room_pid} <- RoomService.find_room(room_id),
         :ok <- Room.hls_subscribe(room_id, origins) do
      send_resp(conn, :created, "Successfully subscribed for tracks")
    else
      :error ->
        {:error, :bad_request, "Invalid request body structure"}

      {:error, :room_not_found} ->
        {:error, :not_found, "Room #{room_id} does not exist"}

      {:error, :component_not_exist} ->
        {:error, :bad_request, "Component with #{component_id} does not exist"}

      {:error, :bad_component_type} ->
        {:error, :bad_request, "Component with #{component_id} is not SIP component"}
    end
  end
end