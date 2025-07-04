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
    :active,
    :vertex_type
  ]

  def start_link({graph_id, vertex_id, name, function, value, vertex_type}) do
    GenServer.start_link(
      __MODULE__,
      {graph_id, vertex_id, name, function, value, vertex_type},
      name: {:via, Registry, {PregelEx.VertexRegistry, {graph_id, vertex_id}}}
    )
  end

  ## Callbacks

  @impl true
  def init({graph_id, vertex_id, name, function, value, vertex_type}) do
    vertex = %__MODULE__{
      graph_id: graph_id,
      id: vertex_id,
      name: name,
      function: function,
      value: value,
      # Messages received but not yet processed
      pending_messages: [],
      # Messages received this superstep
      incoming_messages: [],
      # Map of destination_vertex_id -> Edge struct
      outgoing_edges: %{},
      # Messages to send next superstep
      outgoing_messages: [],
      superstep: 0,
      active: vertex_type == :source,
      vertex_type: vertex_type
    }

    {:ok, vertex}
  end

  defp aggregate_incoming_messages([]), do: nil

  defp aggregate_incoming_messages(messages) do
    # Extract message contents and aggregate them
    contents = Enum.map(messages, & &1.content)

    # Choose aggregation strategy based on content type
    case List.first(contents) do
      value when is_number(value) ->
        # Sum numeric values
        Enum.sum(contents)

      value when is_map(value) ->
        # Merge maps
        Enum.reduce(contents, %{}, &Map.merge/2)

      _ ->
        # Return list for other types
        contents
    end
  end

  @impl true
  def handle_call(
        :compute,
        _from,
        %{active: true, incoming_messages: [], superstep: superstep} = state
      )
      when superstep > 0 do
    state = %{state | active: false}
    {:reply, {:ok, :halt, state.value}, state}
  end

  @impl true
  def handle_call(:compute, _from, %{active: true} = state) do
    aggregated_messages = aggregate_incoming_messages(state.incoming_messages)

    context = %{
      value: state.value,
      raw_messages: state.incoming_messages,
      aggregated_messages: aggregated_messages,
      vertex_id: state.id,
      superstep: state.superstep,
      outgoing_edges: state.outgoing_edges
    }

    # NOTE: the messages adon't look they are auto merging right now.

    IO.puts("Vertex #{state.id} computing with context: #{inspect(context)}")

    result = state.function.(context)
    state_value = state.value

    case result do
      :halt ->
        {:reply, {:ok, :halt, state.value}, %{state | active: false}}

      ^state_value ->
        messages = create_messages_to_neighbors(state, state.value)

        {:reply, {:ok, state.value, messages},
         %{state | outgoing_messages: messages, active: false}}

      new_value ->
        # AUTO-MERGE STATE STRATEGY
        # TODO: create add merge strategy api to configure how merge is done
        # merged_state = merge_with_strategy(
        #   state.value,
        #   new_value,
        #   state.merge_strategy
        # )
        merged_value =
          case state.value do
            nil ->
              new_value

            _ when is_map(state.value) and is_map(new_value) ->
              # If both are maps, merge them
              Map.merge(state.value, new_value)
              # _ when is_list(state.value) and is_list(new_value) ->
              #   # If both are lists, concatenate them
              #   state.value ++ new_value
              # _ when is_number(state.value) and is_number(new_value) ->
              #   # If both are numbers, sum them
              #   state.value + new_value
              # ...
          end

        outgoing_messages = create_messages_to_neighbors(state, merged_value)

        {:reply, {:ok, merged_value, outgoing_messages},
         %{state | value: merged_value, outgoing_messages: outgoing_messages}}
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
    IO.puts("Vertex #{state.id} received messages: #{inspect(messages)}")
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

    IO.puts(
      "Advancing superstep for vertex #{state.id} to #{new_state.superstep} with incoming messages: #{inspect(new_state.incoming_messages)}"
    )

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

  def handle_call(:get_type, _from, state) do
    {:reply, state.vertex_type, state}
  end

  def create_messages_to_neighbors(state, merged_value) do
    neighbor_ids = Map.keys(state.outgoing_edges)

    Enum.map(neighbor_ids, fn neighbor_id ->
      Message.new(state.id, neighbor_id, merged_value, state.superstep)
    end)
  end
end
