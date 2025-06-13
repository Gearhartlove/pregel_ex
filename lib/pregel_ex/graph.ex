defmodule PregelEx.Graph do
  use DynamicSupervisor

  alias PregelEx.Vertex

  def start_link(graph_id) when is_binary(graph_id) do
    DynamicSupervisor.start_link(__MODULE__, graph_id, 
      name: {:via, Registry, {PregelEx.GraphRegistry, graph_id}})
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

  # Callbacks

  @impl true
  def init(_graph_id) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
