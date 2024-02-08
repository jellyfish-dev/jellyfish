defmodule JellyfishWeb.ApiSpec.Dial do
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "DialConfig",
    description: "Dial config",
    type: :object,
    properties: %{
      phoneNumber: %Schema{
        type: :string,
        description: "Phone number on which SIP Component will call"
      }
    }
  })
end