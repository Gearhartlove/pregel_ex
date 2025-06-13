defmodule PregelEx.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Registry for graph lookup by ID
      {Registry, keys: :unique, name: PregelEx.GraphRegistry},
      # Registry for vertex lookup by {graph_id, vertex_id}
      {Registry, keys: :unique, name: PregelEx.VertexRegistry},
      PregelEx.GraphSupervisor
    ]

    opts = [strategy: :one_for_one, name: PregelEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
