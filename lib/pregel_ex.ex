defmodule PregelEx do
  @moduledoc """
  PregelEx - A Pregel-like graph processing framework for Elixir.

  Supports multiple graphs with vertices that can perform distributed computation.
  Each graph runs as a separate supervisor tree with fault tolerance.
  """

  alias PregelEx.{GraphSupervisor, Graph}

  @doc """
  Creates a new graph with the given ID.

  ## Examples

      iex> PregelEx.create_graph("my_graph")
      {:ok, pid, "my_graph"}

  """
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

  ## Examples

      iex> PregelEx.create_vertex("my_graph", "vertex1", fn x -> x + 1 end, initial_value: 10)
      {:ok, vertex_id, pid}

  """
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
  Lists all vertices in a graph.
  """
  def list_vertices(graph_id) do
    Graph.list_vertices(graph_id)
  end
end
