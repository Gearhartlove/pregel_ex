defmodule PregelEx.Graph do
  use DynamicSupervisor

  alias PregelEx.Vertex

  def start_link(graph_id) when is_binary(graph_id) do
    DynamicSupervisor.start_link(__MODULE__, graph_id,
      name: {:via, Registry, {PregelEx.GraphRegistry, graph_id}}
    )
  end

  def create_vertex(graph_id, name, function, opts \\ []) do
    vertex_id =
      :crypto.strong_rand_bytes(16)
      |> Base.encode16(case: :lower)
      |> String.replace_prefix("", "vtx.")

    initial_value = Keyword.get(opts, :initial_value, %{})

    child_spec = %{
      id: :unknown,
      start: {Vertex, :start_link, [{graph_id, vertex_id, name, function, initial_value}]}
    }

    case Registry.lookup(PregelEx.GraphRegistry, graph_id) do
      [{graph_pid, _}] ->
        case DynamicSupervisor.start_child(graph_pid, child_spec) do
          {:ok, vertex_pid} -> {:ok, vertex_id, vertex_pid}
          error -> error
        end

      [] ->
        {:error, :graph_not_found}
    end
  end

  def stop_vertex(graph_id, vertex_id) do
    case get_vertex_pid(graph_id, vertex_id) do
      {:ok, vertex_pid} ->
        case Registry.lookup(PregelEx.GraphRegistry, graph_id) do
          [{graph_pid, _}] ->
            DynamicSupervisor.terminate_child(graph_pid, vertex_pid)

          [] ->
            {:error, :graph_not_found}
        end

      error ->
        error
    end
  end

  def get_vertex_count(graph_id) do
    case Registry.lookup(PregelEx.GraphRegistry, graph_id) do
      [{graph_pid, _}] ->
        graph_pid
        |> DynamicSupervisor.which_children()
        |> length()

      [] ->
        {:error, :graph_not_found}
    end
  end

  def get_vertex_pid(graph_id, vertex_id) do
    case Registry.lookup(PregelEx.VertexRegistry, {graph_id, vertex_id}) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  def get_vertex_state(graph_id, vertex_id) do
    case get_vertex_pid(graph_id, vertex_id) do
      {:ok, pid} ->
        GenServer.call(pid, :get_state)

      {:error, :not_found} ->
        {:error, :vertex_not_found}
    end
  end

  def list_vertices(graph_id) do
    case Registry.lookup(PregelEx.GraphRegistry, graph_id) do
      [{graph_pid, _}] ->
        children = DynamicSupervisor.which_children(graph_pid)
        {:ok, Enum.map(children, fn {_id, pid, _type, _modules} -> pid end)}

      [] ->
        {:error, :graph_not_found}
    end
  end

  def compute_vertex(graph_id, vertex_id) do
    case get_vertex_pid(graph_id, vertex_id) do
      {:ok, pid} ->
        GenServer.call(pid, :compute)

      {:error, :not_found} ->
        {:error, :vertex_not_found}
    end
  end

  @doc """
  Creates an edge between two vertices in the graph.
  
  This adds the edge to the source vertex's outgoing edges list.
  The edge contains the destination vertex ID, weight, and optional properties.
  
  ## Parameters
  - graph_id: The ID of the graph containing the vertices
  - from_vertex_id: The source vertex ID
  - to_vertex_id: The destination vertex ID  
  - weight: The weight/cost of the edge (defaults to 1)
  - properties: Additional metadata for the edge (defaults to empty map)
  
  ## Returns
  - {:ok, edge} on success
  - {:error, reason} on failure
  """
  def create_edge(graph_id, from_vertex_id, to_vertex_id, weight \\ 1, properties \\ %{}) do
    # Verify both vertices exist
    with {:ok, from_pid} <- get_vertex_pid(graph_id, from_vertex_id),
         {:ok, _to_pid} <- get_vertex_pid(graph_id, to_vertex_id) do
      # Add the outgoing edge to the source vertex
      GenServer.call(from_pid, {:add_outgoing_edge, to_vertex_id, weight, properties})
    else
      {:error, :not_found} -> {:error, :vertex_not_found}
      error -> error
    end
  end

  @doc """
  Removes an edge between two vertices.
  """
  def remove_edge(graph_id, from_vertex_id, to_vertex_id) do
    case get_vertex_pid(graph_id, from_vertex_id) do
      {:ok, from_pid} ->
        GenServer.call(from_pid, {:remove_outgoing_edge, to_vertex_id})
      {:error, :not_found} ->
        {:error, :vertex_not_found}
    end
  end

  @doc """
  Gets all outgoing edges for a vertex.
  """
  def get_vertex_edges(graph_id, vertex_id) do
    case get_vertex_pid(graph_id, vertex_id) do
      {:ok, pid} ->
        GenServer.call(pid, :get_outgoing_edges)
      {:error, :not_found} ->
        {:error, :vertex_not_found}
    end
  end

  @doc """
  Gets all neighbor vertex IDs for a vertex (vertices with outgoing edges).
  """
  def get_vertex_neighbors(graph_id, vertex_id) do
    case get_vertex_pid(graph_id, vertex_id) do
      {:ok, pid} ->
        GenServer.call(pid, :get_neighbors)
      {:error, :not_found} ->
        {:error, :vertex_not_found}
    end
  end

  @doc """
  Lists all edges in the graph by collecting outgoing edges from all vertices.
  """
  def list_edges(graph_id) do
    case list_vertices(graph_id) do
      {:ok, vertex_pids} ->
        edges = 
          vertex_pids
          |> Enum.flat_map(fn pid ->
            case GenServer.call(pid, :get_outgoing_edges) do
              {:ok, edges} -> edges
              _ -> []
            end
          end)
        {:ok, edges}
      error -> error
    end
  end

  # Callbacks

  @impl true
  def init(_graph_id) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
