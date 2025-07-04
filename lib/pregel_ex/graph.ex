defmodule PregelEx.Graph do
  use DynamicSupervisor

  require Logger
  alias PregelEx.Vertex

  def start_link(graph_id) when is_binary(graph_id) do
    DynamicSupervisor.start_link(__MODULE__, graph_id,
      name: {:via, Registry, {PregelEx.GraphRegistry, graph_id}}
    )
  end

  @spec create_vertex(String.t(), String.t(), (map() -> map()), keyword()) ::
          {:ok, String.t(), pid()} | {:error, atom()}
  def create_vertex(graph_id, name, function, opts \\ []) do
    value = Keyword.get(opts, :value)
    vertex_type = Keyword.get(opts, :type, :normal)

    vertex_id =
      :crypto.strong_rand_bytes(16)
      |> Base.encode16(case: :lower)
      |> String.replace_prefix("", "vtx.")

    child_spec = %{
      id: :unknown,
      start: {Vertex, :start_link, [{graph_id, vertex_id, name, function, value, vertex_type}]}
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

      error ->
        error
    end
  end

  @doc """
  Sends a message from one vertex to another.
  """
  def send_message(graph_id, from_vertex_id, to_vertex_id, content) do
    with {:ok, from_pid} <- get_vertex_pid(graph_id, from_vertex_id),
         {:ok, _to_pid} <- get_vertex_pid(graph_id, to_vertex_id) do
      GenServer.call(from_pid, {:send_message, to_vertex_id, content})
    else
      error -> error
    end
  end

  @doc """
  Clears all outgoing messages for a vertex.
  """
  def clear_outgoing_messages(graph_id, vertex_id) do
    case get_vertex_pid(graph_id, vertex_id) do
      {:ok, pid} ->
        GenServer.call(pid, :clear_outgoing_messages)

      {:error, :not_found} ->
        {:error, :vertex_not_found}
    end
  end

  # Callbacks

  @impl true
  def init(_graph_id) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  # Superstep coordinator orchestrates the flow
  def execute_superstep(graph_id) do
    with :ok <- compute_all_active_vertices(graph_id),
         {:ok, messages} <- collect_all_outgoing_messages(graph_id),
         :ok <- deliver_messages_to_recipients(graph_id, messages),
         :ok <- clear_all_outgoing_messages(graph_id),
         :ok <- advance_all_vertices_superstep(graph_id) do
      check_termination_condition(graph_id)
    end
  end

  @doc """
  Invokes the `:compute` operation on all active vertices in the graph identified by `graph_id`.

  This function performs the following steps:
  1. Retrieves the list of vertex process IDs (PIDs) for the given `graph_id`.
  2. Filters the list to include only those vertices whose state is `:active`.
  3. For each active vertex, calls the `:compute` operation via `GenServer.call/2`.
  4. Returns `:ok` if successful, or propagates any error encountered during vertex retrieval.

  ## Parameters

    - `graph_id`: The identifier of the graph whose active vertices should be computed.

  ## Returns

    - `:ok` on success.
    - An error tuple if the vertex list could not be retrieved.
  """
  def compute_all_active_vertices(graph_id) do
    case list_vertices(graph_id) do
      {:ok, vertex_pids} ->
        vertex_pids
        |> Enum.filter(fn pid ->
          case GenServer.call(pid, :active?) do
            true -> true
            false -> false
          end
        end)
        |> IO.inspect(label: "Active vertex PIDs for graph #{graph_id}")
        |> Enum.each(fn pid ->
          GenServer.call(pid, :compute)
        end)

        :ok

      error ->
        error
    end
  end

  @doc """
  Collects all outgoing messages from the vertices of the specified graph.

  Given a `graph_id`, this function retrieves the list of vertex process IDs,
  then queries each vertex for its outgoing messages using a GenServer call.
  It aggregates all messages into a single list and returns them in an `{:ok, messages}` tuple.
  If there is an error retrieving the vertices, the error is returned as is.

  ## Parameters

    - `graph_id`: The identifier of the graph whose vertices' outgoing messages are to be collected.

  ## Returns

    - `{:ok, messages}`: A tuple containing the list of all outgoing messages from all vertices.
    - `error`: Any error encountered while retrieving the list of vertices.

  """
  def collect_all_outgoing_messages(graph_id) do
    case list_vertices(graph_id) do
      {:ok, vertex_pids} ->
        vertex_pids
        |> Enum.flat_map(fn pid ->
          case GenServer.call(pid, :get_outgoing_messages) do
            {:ok, messages} -> messages
            _ -> []
          end
        end)
        |> then(&{:ok, &1})
        |> IO.inspect(label: "Collected messages for graph #{graph_id}")

      error ->
        error
    end
  end

  @doc """
  Delivers a list of messages to their respective recipient vertices within the specified graph.

  Each message is grouped by its recipient vertex ID. For each group, the function attempts to find the process ID (PID) of the recipient vertex using `get_vertex_pid/2`. If the vertex exists, the messages are delivered to it via a synchronous `GenServer.call/2`. If the vertex does not exist, the function handles the case gracefully (currently by doing nothing).

  ## Parameters

    - `graph_id`: The identifier of the graph containing the vertices.
    - `messages`: A list of `%PregelEx.Message{}` structs to be delivered.

  ## Returns

    - `:ok` after attempting to deliver all messages.

  ## Notes

    - If a recipient vertex does not exist, the function does not deliver the messages and simply continues.
    - This function is side-effecting and intended for internal message passing within the PregelEx graph processing framework.
  """
  def deliver_messages_to_recipients(graph_id, messages) do
    # group message by recipient vertex ID
    messages
    |> Enum.group_by(& &1.to_vertex_id)
    |> Enum.each(fn {to_vertex_id, msgs} ->
      case get_vertex_pid(graph_id, to_vertex_id) do
        {:ok, pid} ->
          GenServer.call(pid, {:receive_messages, msgs})

        {:error, :not_found} ->
          # Log or handle the case where the recipient vertex does not exist
          Logger.warning(
            "Recipient vertex #{to_vertex_id} not found for messages: #{inspect(msgs)}"
          )

          :ok
      end
    end)

    :ok
  end

  @doc """
  Clears all outgoing messages for every vertex in the specified graph.

  Given a `graph_id`, this function retrieves all vertex process IDs associated with the graph,
  and sends each one a synchronous call to clear its outgoing messages.

  ## Parameters

    - `graph_id`: The identifier of the graph whose vertices' outgoing messages should be cleared.

  ## Returns

    - `:ok` if all outgoing messages were successfully cleared.
    - An error tuple if the vertices could not be listed.

  ## Examples

      iex> clear_all_outgoing_messages("my_graph")
      :ok
  """
  def clear_all_outgoing_messages(graph_id) do
    case list_vertices(graph_id) do
      {:ok, vertex_pids} ->
        vertex_pids
        |> Enum.each(fn pid ->
          GenServer.call(pid, :clear_outgoing_messages)
        end)

        :ok

      error ->
        error
    end
  end

  @doc """
  Advances all vertices in the graph to the next superstep.

  Given a `graph_id`, this function retrieves all vertex process IDs associated with the graph
  and sends each one a synchronous `:advance_superstep` message via `GenServer.call/2`.
  Returns `:ok` if successful, or propagates any error encountered when listing vertices.

  ## Parameters

    - `graph_id`: The identifier of the graph whose vertices should be advanced.

  ## Returns

    - `:ok` on success.
    - An error tuple if listing vertices fails.
  """
  def advance_all_vertices_superstep(graph_id) do
    case list_vertices(graph_id) do
      {:ok, vertex_pids} ->
        vertex_pids
        |> Enum.each(fn pid ->
          GenServer.call(pid, :advance_superstep)
        end)

        :ok

      error ->
        error
    end
  end

  def check_termination_condition(graph_id) do
    case list_vertices(graph_id) do
      {:ok, vertex_pids} ->
        active_vertices =
          vertex_pids
          |> Enum.filter(fn pid ->
            GenServer.call(pid, :active?)
          end)

        active_count = length(active_vertices)

        if active_count == 0 do
          {:halted,
           "All vertices have voted to halt, terminating superstep for graph #{graph_id}"}
        else
          {:continue,
           "#{active_count} active vertices remain, continuing superstep for graph #{graph_id}. Active vertices: #{inspect(active_vertices)}"}
        end

      error ->
        error
    end
  end

  def run(graph_id, opts \\ []) do
    max_supersteps = Keyword.get(opts, :max_supersteps, 1000)
    timeout = Keyword.get(opts, :timeout, 60_000)

    IO.puts(
      "Running graph #{graph_id} with max_supersteps=#{max_supersteps}, timeout=#{timeout}ms"
    )

    run_with_limits(graph_id, 0, [], max_supersteps, timeout)
  end

  def run_with_limits(graph_id, superstep, log, max_supersteps, timeout) do
    start_time = System.monotonic_time(:millisecond)

    cond do
      superstep >= max_supersteps ->
        {:error, {:max_supersteps_exceeded, superstep}}

      System.monotonic_time(:millisecond) - start_time > timeout ->
        {:error, {:timeout_exceeded, superstep}}

      true ->
        case execute_superstep(graph_id) do
          {:halted, reason} ->
            Logger.info("Graph #{graph_id} halted: #{reason}")

            :ok

          {:continue, status} ->
            Logger.info("Graph #{graph_id} continuing: #{status}")

            run_with_limits(
              graph_id,
              superstep + 1,
              log ++ [status],
              max_supersteps,
              timeout
            )

          error ->
            Logger.error(
              "Error during superstep #{superstep} for graph #{graph_id}: #{inspect(error)}"
            )

            {:error, error}
        end
    end
  end

  def get_final_value(graph_id) do
    case list_vertices(graph_id) do
      {:ok, vertex_pids} ->
        final_vertex =
          vertex_pids
          |> Enum.find(fn pid ->
            GenServer.call(pid, :get_type) == :final
          end)

        if final_vertex do
          GenServer.call(final_vertex, :get_state)
        else
          {:error, :final_vertex_not_found}
        end

      error ->
        error
    end
  end
end
