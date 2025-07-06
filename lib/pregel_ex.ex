defmodule PregelEx do
  @moduledoc """
  PregelEx - A Pregel-like graph processing framework for Elixir.

  Supports multiple graphs with vertices that can perform distributed computation.
  Each graph runs as a separate supervisor tree with fault tolerance.
  """

  alias PregelEx.{GraphSupervisor, Graph}

  @doc """
  Creates a new graph with the given ID.
  """
  @spec create_graph(String.t()) :: {:ok, String.t(), pid()} | {:error, atom()}
  def create_graph(graph_id) when is_binary(graph_id) do
    GraphSupervisor.create_graph(graph_id)
  end

  @doc """
  Stops a graph and all its vertices.
  """
  def stop_graph(graph_id) do
    GraphSupervisor.stop_graph(graph_id)
  end

  @doc """
  Lists all active graphs.
  """
  def list_graphs do
    GraphSupervisor.list_graphs()
  end

  @doc """
  Gets the count of active graphs.
  """
  def get_graph_count do
    GraphSupervisor.get_graph_count()
  end

  @doc """
  Creates a vertex in the specified graph.
  """
  @spec create_vertex(String.t(), String.t(), (map() -> map()), keyword()) ::
          {:ok, String.t(), pid()} | {:error, atom()}
  def create_vertex(graph_id, name, function, opts \\ []) do
    Graph.create_vertex(graph_id, name, function, opts)
  end

  @doc """
  Stops a vertex in the specified graph.
  """
  def stop_vertex(graph_id, vertex_id) do
    Graph.stop_vertex(graph_id, vertex_id)
  end

  @doc """
  Gets the count of vertices in a graph.
  """
  def get_vertex_count(graph_id) do
    Graph.get_vertex_count(graph_id)
  end

  @doc """
  Gets the state of a vertex in a graph.
  """
  def get_vertex_state(graph_id, vertex_id) do
    Graph.get_vertex_state(graph_id, vertex_id)
  end

  @doc """
  Creates an edge between two vertices in a graph.

  ## Parameters
  - graph_id: The ID of the graph containing the vertices
  - from_vertex_id: The source vertex ID
  - to_vertex_id: The destination vertex ID
  - weight: The weight/cost of the edge (defaults to 1)
  - properties: Additional metadata for the edge (defaults to empty map)

  ## Examples

      {:ok, edge} = PregelEx.create_edge(graph_id, "vtx.abc", "vtx.def", 2.5)
      {:ok, edge} = PregelEx.create_edge(graph_id, "vtx.abc", "vtx.def", 1, %{type: "friendship"})
  """
  def create_edge(graph_id, from_vertex_id, to_vertex_id, weight \\ 1, properties \\ %{}) do
    Graph.create_edge(graph_id, from_vertex_id, to_vertex_id, weight, properties)
  end

  @doc """
  Removes an edge between two vertices.
  """
  def remove_edge(graph_id, from_vertex_id, to_vertex_id) do
    Graph.remove_edge(graph_id, from_vertex_id, to_vertex_id)
  end

  @doc """
  Gets all outgoing edges for a vertex.
  """
  def get_vertex_edges(graph_id, vertex_id) do
    Graph.get_vertex_edges(graph_id, vertex_id)
  end

  @doc """
  Gets all neighbor vertex IDs for a vertex.
  """
  def get_vertex_neighbors(graph_id, vertex_id) do
    Graph.get_vertex_neighbors(graph_id, vertex_id)
  end

  @doc """
  Lists all edges in the graph.
  """
  def list_edges(graph_id) do
    Graph.list_edges(graph_id)
  end

  @doc """
  Lists all vertices in a graph.
  """
  def list_vertices(graph_id) do
    Graph.list_vertices(graph_id)
  end

  @doc """
  Computes a vertex in the specified graph.
  """
  def compute_vertex(graph_id, vertex_id) do
    Graph.compute_vertex(graph_id, vertex_id)
  end

  @doc """
  Sends a message from one vertex to another in the specified graph.
  """
  def send_message(graph_id, from_vertex_id, to_vertex_id, content) do
    Graph.send_message(graph_id, from_vertex_id, to_vertex_id, content)
  end

  @doc """
  Clears all outgoing messages for a vertex in the specified graph.
  """
  def clear_outgoing_messages(graph_id, vertex_id) do
    Graph.clear_outgoing_messages(graph_id, vertex_id)
  end

  @doc """
  Executes a superstep for the given graph.

  ## Parameters

    - `graph_id`: The identifier of the graph on which to execute the superstep.

  ## Returns

    - The result of executing the superstep, as returned by `Graph.execute_superstep/1`.
  """
  def execute_superstep(graph_id) do
    Graph.execute_superstep(graph_id)
  end

  def run(graph_id, opts \\ []) do
    Graph.run(graph_id, opts)
  end

  def get_final_value(graph_id) do
    Graph.get_final_value(graph_id)
  end
end
