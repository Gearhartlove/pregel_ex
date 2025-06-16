defmodule PregelEx.GraphSupervisor do
  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def create_graph(graph_id) when is_binary(graph_id) do
    child_spec = %{
      id: graph_id,
      start: {PregelEx.Graph, :start_link, [graph_id]}
    }

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} -> {:ok, pid, graph_id}
      {:error, {:already_started, pid}} -> {:ok, pid, graph_id}
      error -> error
    end
  end

  def stop_graph(graph_id) do
    case Registry.lookup(PregelEx.GraphRegistry, graph_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :graph_not_found}
    end
  end

  def list_graphs do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
  end

  def get_graph_count do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> length()
  end

  def stop_all_graphs do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> Enum.each(fn {_id, pid, _type, _modules} ->
      DynamicSupervisor.terminate_child(__MODULE__, pid)
    end)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
