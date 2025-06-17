defmodule PregelEx.Edge do
  @moduledoc """
  Represents an edge in the graph connecting two vertices.

  An edge contains:
  - `from_vertex_id`: The source vertex ID
  - `to_vertex_id`: The destination vertex ID
  - `weight`: Optional weight/value associated with the edge (defaults to 1)
  - `properties`: Additional metadata for the edge
  """

  defstruct [
    :from_vertex_id,
    :to_vertex_id,
    weight: 1,
    properties: %{}
  ]

  @type t :: %__MODULE__{
          from_vertex_id: String.t(),
          to_vertex_id: String.t(),
          weight: number(),
          properties: map()
        }

  @doc """
  Creates a new edge with the given parameters.

  ## Examples

      iex> PregelEx.Edge.new("vtx.abc123", "vtx.def456", 2.5)
      %PregelEx.Edge{
        from_vertex_id: "vtx.abc123",
        to_vertex_id: "vtx.def456",
        weight: 2.5,
        properties: %{}
      }
  """
  def new(from_vertex_id, to_vertex_id, weight \\ 1, properties \\ %{}) do
    %__MODULE__{
      from_vertex_id: from_vertex_id,
      to_vertex_id: to_vertex_id,
      weight: weight,
      properties: properties
    }
  end
end
