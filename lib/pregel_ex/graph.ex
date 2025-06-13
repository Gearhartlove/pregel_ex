defmodule PregelEx.Graph do
  use DynamicSupervisor

  alias PregelEx.Vertex

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def create_vertex(name, function, opts \\ []) do
    vertex_id =
      :crypto.strong_rand_bytes(16)
      |> Base.encode16(case: :lower)
      |> String.replace_prefix("", "vtx.")

    initial_value = Keyword.get(opts, :initial_value, %{})

    child_spec = %{
      id: :unknown,
      start: {Vertex, :start_link, [{vertex_id, name, function, initial_value}]}
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)

    {:ok, vertex_id}
  end

  def stop_vertex(vertex_id) do
    case DynamicSupervisor.terminate_child(__MODULE__, vertex_id) do
      :ok -> :ok
      {:error, :not_found} -> {:error, :vertex_not_found}
    end
  end

  def get_vertex_count do
    __MODULE__
    |> DynamicSupervisor.which_children()
    |> length()
  end

  def get_vertex_pid(vertex_id) do
    case Registry.lookup(PregelEx.VertexRegistry, vertex_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  def get_vertex_state(vertex_id) do
    case get_vertex_pid(vertex_id) do
      {:ok, pid} ->
        GenServer.call(pid, :get_state)

      {:error, :not_found} ->
        {:error, :vertex_not_found}
    end
  end

  # Callbacks

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
