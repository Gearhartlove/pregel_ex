defmodule PregelEx.Vertex do
  use GenServer

  @doc """
  start_link/1 starts a new vertex process with the given parameters.
  It takes a tuple containing the vertex ID, name, function to compute the value,
  and an initial value for the vertex.
  The vertex ID is a unique identifier for the vertex, the name is a human-readable
  name, the function is a callback that will be used to compute the vertex's value,
  and the initial value is the starting state of the vertex.
  ## Parameters
  - vertex_id: A unique identifier for the vertex.
  - name: A human-readable name for the vertex.
  - function: A function that takes the current value and returns a new value.
  - initial_value: The initial value of the vertex.
  ## Returns
  - `{:ok, pid}` on success, where `pid` is the process identifier of the vertex.
  - `{:error, reason}` on failure, where `reason` is the error reason.
  ## Example
      iex> PregelEx.Vertex.start_link({:vertex1, "Vertex 1", fn x -> x + 1 end, 0})
      {:ok, #PID<0.123.0>}
  """
  def start_link({vertex_id, name, function, initial_value}) do
    GenServer.start_link(
      __MODULE__,
      {vertex_id, name, function, initial_value},
      name: {:via, Registry, {PregelEx.VertexRegistry, vertex_id}}
    )
  end

  ## Callbacks

  @impl true
  def init({vertex_id, name, function, initial_value}) do
    state = %{
      id: vertex_id,
      name: name,
      function: function,
      value: initial_value,
      state: :inactive,
      neighbors: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:compute}, _from, state) do
    function = state.function
    new_value = function.(state.value)
    new_state = %{state | value: new_value, state: :inactive}
    {:reply, {:ok, new_value}, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end
end
