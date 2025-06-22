defmodule PregelEx.Vertex do
  use GenServer

  alias PregelEx.Message

  defstruct [
    :graph_id,
    :id,
    :name,
    :function,
    :value,
    :outgoing_edges,
    :pending_messages,
    :incoming_messages,
    :outgoing_messages,
    :superstep,
    :active
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
      # Messages received but not yet processed
      pending_messages: [],
      # Messages received this superstep
      incoming_messages: [],
      # Map of destination_vertex_id -> Edge struct
      outgoing_edges: %{},
      # Messages to send next superstep
      outgoing_messages: [],
      superstep: 0,
      active: true
    }

    {:ok, vertex}
  end

  @impl true
  def handle_call(:compute, _from, %{active: true} = state) do
    result = state.function.({state.value, state.incoming_messages, state.id})

    case result do
      {:ok, new_value} ->
        {:reply, {:ok, new_value}, %{state | value: new_value}}

      {:ok, new_value, :halt} ->
        {:reply, {:ok, new_value}, %{state | value: new_value, active: false}}

      {:ok, new_value, messages_to_send}
      when is_list(messages_to_send) ->
        outgoing_messages =
          Enum.map(messages_to_send, fn {to_vertex_id, content} ->
            Message.new(state.id, to_vertex_id, content, state.superstep)
          end)

        {
          :reply,
          {:ok, new_value},
          %{
            state
            | value: new_value,
              outgoing_messages: state.outgoing_messages ++ outgoing_messages
          }
        }

      error ->
        {:reply, {:error, error}, state}
    end
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
    has_messages = length(state.pending_messages) > 0

    new_state = %{
      state
      | superstep: state.superstep + 1,
        incoming_messages: state.pending_messages,
        pending_messages: [],
        active: has_messages or state.active
    }

    {:reply, :ok, new_state}
  end

  def handle_call(:active?, _from, state) do
    {:reply, state.active, state}
  end

  def handle_call(:vote_to_halt, _from, state) do
    new_state = %{state | active: false}
    {:reply, :ok, new_state}
  end

  def handle_call(:activate, _from, state) do
    new_state = %{state | active: true}
    {:reply, :ok, new_state}
  end
end
