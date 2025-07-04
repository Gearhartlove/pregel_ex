defmodule PregelEx.Builder do
  defstruct [
    # Name of the builder
    :name,
    # List of vertices in the graph
    :vertices,
    # List of edges connecting the vertices
    :edges
  ]

  @type t :: %__MODULE__{
          name: String.t(),
          vertices: list(map()),
          edges: list(tuple())
        }

  def type, do: :builder

  @doc """
  Initializes a new graph builder with the given name.
  """
  def build(name) do
    # Initialize the builder with the given name
    %__MODULE__{
      name: name,
      vertices: [],
      edges: []
    }
  end

  @doc """
  Adds a vertex to the builder.

  # Validation
  - The vertex must have a unique name.
  """
  @spec add_vertex(__MODULE__.t(), String.t(), (map() -> map()), keyword()) :: __MODULE__.t()
  def add_vertex(builder, name, function, opts \\ []) do
    builder.vertices
    |> Enum.find(fn v -> v.name == name end)
    |> case do
      nil ->
        # Vertex does not exist, create a new one
        vertex = %{
          name: name,
          function: function,
          type: Keyword.get(opts, :type, :normal),
          opts: opts
        }

        %{builder | vertices: builder.vertices ++ [vertex]}

      _ ->
        # Vertex already exists, raise an error
        raise ArgumentError, "Vertex with name '#{name}' already exists in the builder."
    end
  end

  @doc """
  Adds an edge between two vertices in the builder.

  # Validation
  - Both vertices must exist in the builder.
  """
  @spec add_edge(__MODULE__.t(), binary(), binary()) :: :ok | {:error, String.t()}
  def add_edge(builder, source, target) do
    with {:ok, source_vertex} <- find_vertex(builder, source),
         {:ok, target_vertex} <- find_vertex(builder, target) do
      # Both vertices exist, add the edge
      edge = {source_vertex.name, target_vertex.name}
      %{builder | edges: builder.edges ++ [edge]}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates the graph using the builder's properties.
  """
  # @spec create_graph(__MODULE__.t()) :: {:ok, String.t()} | {:error, String.t()}
  def finish(builder) do
    # Take 3
    case PregelEx.create_graph(builder.name) do
      {:ok, graph_id, graph_pid} ->
        try do
          # TODO: fail on errors
          # Note: does not collect errors currently
          # Add vertices
          verticies =
            Enum.map(builder.vertices, fn vertex ->
              PregelEx.create_vertex(graph_id, vertex.name, vertex.function, vertex.opts)
            end)

          # Turn verticies into a map for easy lookup of vertex IDs to names
          vertex_map = Enum.into(verticies, %{}, fn {:ok, id, _pid, name} -> {name, id} end)

          # TODO: fail on errors
          # NOTE: does not collect errors currently
          # Add edges
          _edges =
            Enum.map(builder.edges, fn {source, target} ->
              source_id = Map.get(vertex_map, source)
              target_id = Map.get(vertex_map, target)
              PregelEx.create_edge(graph_id, source_id, target_id)
            end)

          {:ok, graph_id, graph_pid}
        rescue
          e ->
            if graph_pid and Process.alive?(graph_pid) do
              DynamicSupervisor.stop(graph_pid, :normal)
            end

            {:error, "Failed to create graph: #{inspect(e)}"}
        end

      {:error, reason} ->
        {:error, "Failed to create graph: #{reason}"}
    end
  end

  # This functions finds a vertex by its name in the builder.
  @spec find_vertex(__MODULE__.t(), String.t()) :: {:ok, map()} | {:error, String.t()}
  defp find_vertex(builder, name) do
    case Enum.find(builder.vertices, fn v -> v.name == name end) do
      nil -> {:error, "Vertex '#{name}' not found in the builder."}
      vertex -> {:ok, vertex}
    end
  end
end
