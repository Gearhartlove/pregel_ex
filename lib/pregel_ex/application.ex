defmodule PregelEx.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: PregelEx.VertexRegistry},
      PregelEx.Graph
    ]

    opts = [strategy: :one_for_one, name: PregelEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
