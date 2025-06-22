defmodule PregelEx.Vertex do
  use GenServer

  alias PregelEx.Message

  defstruct [
    :graph_id,
    :id,
    :name,
    :function,
    :value,
    # active or inactive
    :state,
    :outgoing_edges,
    # Messages received but not yet processed
    :pending_messages,
    :incoming_messages,
    :outgoing_messages,
    :superstep
  ]

  def start_link({graph_id, vertex_id, name, function, initial_value}) do
    GenServer.start_link(
      __MODULE__,
      {graph_id, vertex_id, name, function, initial_value},
      name: {:via, Registry, {PregelEx.VertexRegistry, {graph_id, vertex_id}}}
    )
  end

  ## Callbacks

  @impl true
  def init({graph_id, vertex_id, name, function, initial_value}) do
    vertex = %__MODULE__{
      graph_id: graph_id,
      id: vertex_id,
      name: name,
      function: function,
      value: initial_value,
      state: :inactive,
      # Messages received but not yet processed
      pending_messages: [],
      # Messages received this superstep
      incoming_messages: [],
      # Map of destination_vertex_id -> Edge struct
      outgoing_edges: %{},
      # Messages to send next superstep
      outgoing_messages: [],
      superstep: 0
    }

    {:ok, vertex}
  end

  @impl true
  def handle_call(:compute, _from, state) do
    function = state.function
    new_value = function.(state.value)
    new_state = %{state | value: new_value, state: :inactive}
    {:reply, {:ok, new_value}, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_call({:add_outgoing_edge, to_vertex_id, weight, properties}, _from, state) do
    edge = PregelEx.Edge.new(state.id, to_vertex_id, weight, properties)
    new_outgoing_edges = Map.put(state.outgoing_edges, to_vertex_id, edge)
    new_state = %{state | outgoing_edges: new_outgoing_edges}
    {:reply, {:ok, edge}, new_state}
  end

  @impl true
  def handle_call({:remove_outgoing_edge, to_vertex_id}, _from, state) do
    case Map.pop(state.outgoing_edges, to_vertex_id) do
      {nil, _} ->
        {:reply, {:error, :edge_not_found}, state}

      {edge, new_outgoing_edges} ->
        new_state = %{state | outgoing_edges: new_outgoing_edges}
        {:reply, {:ok, edge}, new_state}
    end
  end

  @impl true
  def handle_call(:get_outgoing_edges, _from, state) do
    edges = Map.values(state.outgoing_edges)
    {:reply, {:ok, edges}, state}
  end

  @impl true
  def handle_call(:get_neighbors, _from, state) do
    neighbor_ids = Map.keys(state.outgoing_edges)
    {:reply, {:ok, neighbor_ids}, state}
  end

  @impl true
  def handle_call({:send_message, to_vertex_id, content}, _from, state) do
    message = Message.new(state.id, to_vertex_id, content, state.superstep)
    new_outgoing = [message | state.outgoing_messages]
    {:reply, :ok, %{state | outgoing_messages: new_outgoing}}
  end

  def handle_call(:get_outgoing_messages, _from, state) do
    {:reply, {:ok, state.outgoing_messages}, state}
  end

  def handle_call(:clear_outgoing_messages, _from, state) do
    {:reply, :ok, %{state | outgoing_messages: []}}
  end

  def handle_call({:receive_messages, messages}, _from, state) do
    # Add to pending (will become incoming on the next superstep)
    new_pending = state.pending_messages ++ messages
    new_state = %{state | pending_messages: new_pending}
    {:reply, :ok, new_state}
  end

  def handle_call(:advance_superstep, _from, state) do
    new_state = %{
      state
      | superstep: state.superstep + 1,
        incoming_messages: state.pending_messages,
        pending_messages: []
    }

    {:reply, :ok, new_state}
  end
end
