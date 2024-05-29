defmodule Fishjam.Room.ID do
  @moduledoc """
  This module allows to generate room_id with the node name in it.
  """

  @doc """
  Based on the Room ID determines to which node it belongs to.
  If the node is not persistent in cluster returns error.
  """
  @spec determine_node(String.t()) ::
          {:ok, node()} | {:error, :invalid_room_id} | {:error, :invalid_node}
  def determine_node(room_id) do
    with {:ok, room_id} <- validate_room_id(room_id),
         node_name <- decode_node_name(room_id),
         true <- node_persistent_in_cluster?(node_name) do
      {:ok, node_name}
    else
      {:error, :invalid_room_id} -> {:error, :invalid_room_id}
      false -> {:error, :invalid_node}
    end
  end

  @doc """
  Room ID structure resembles the one of the UUID, although the last part is replaced by node name hash.

  ## Example:
      For node_name: "fishjam@10.0.0.1"

      iex> Fishjam.Room.ID.generate()
      "da2e-4a75-95ff-776bad2caf04-666973686a616d4031302e302e302e31"
  """
  @spec generate() :: String.t()
  def generate do
    UUID.uuid4()
    |> String.split("-")
    |> Enum.take(-4)
    |> Enum.concat([encoded_node_name()])
    |> Enum.join("-")
  end

  @doc """
  Depending on feature flag:
    - uses `generate/0` to generate room_id
    or
    - parses the `room_id` provided by the client
  """
  @spec generate(nil | String.t()) :: {:ok, String.t()} | {:error, :invalid_room_id}
  def generate(room_id) do
    if Fishjam.FeatureFlags.custom_room_name_disabled?() do
      {:ok, generate()}
    else
      validate_room_id(room_id)
    end
  end

  defp decode_node_name(room_id) do
    room_id
    |> String.split("-")
    |> Enum.take(-1)
    |> Enum.at(0)
    |> Base.decode16!(case: :lower)
    |> String.to_atom()
  end

  defp encoded_node_name do
    Node.self()
    |> Atom.to_string()
    |> Base.encode16(case: :lower)
  end

  defp node_persistent_in_cluster?(node) do
    node in [Node.self() | Node.list()]
  end

  defp validate_room_id(nil), do: validate_room_id(UUID.uuid4())

  defp validate_room_id(room_id) when is_binary(room_id) do
    if Regex.match?(~r/^[a-zA-Z0-9-_]+$/, room_id) do
      {:ok, room_id}
    else
      {:error, :invalid_room_id}
    end
  end

  defp validate_room_id(_room_id), do: {:error, :invalid_room_id}
end
