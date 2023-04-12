defmodule Jellyfish.Component.RTSP do
  @moduledoc """
  Module representing the RTSP component.
  """

  @behaviour Jellyfish.Endpoint.Config

  alias Membrane.RTC.Engine.Endpoint.RTSP

  alias JellyfishWeb.ApiSpec

  @impl true
  def config(%{engine_pid: engine} = options) do
    options = Map.drop(options, [:engine_pid, :room_id])

    with {:ok, valid_opts} <- OpenApiSpex.cast_value(options, ApiSpec.Component.RTSP.schema()) do
      component_spec =
        Map.from_struct(valid_opts)
        |> Map.put(:rtc_engine, engine)
        |> then(&struct(RTSP, &1))

      {:ok, component_spec}
    else
      {:error, _reason} = error -> error
    end
  end
end
