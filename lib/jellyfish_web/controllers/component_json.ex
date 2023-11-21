defmodule JellyfishWeb.ComponentJSON do
  @moduledoc false

  alias Jellyfish.Component.{HLS, RTSP}
  alias Jellyfish.Utils

  def show(%{component: component}) do
    %{data: data(component)}
  end

  def data(component) do
    type =
      case component.type do
        HLS -> "hls"
        RTSP -> "rtsp"
      end

    %{
      id: component.id,
      type: type,
      properties: component.properties |> Utils.camel_case_keys()
    }
  end
end
