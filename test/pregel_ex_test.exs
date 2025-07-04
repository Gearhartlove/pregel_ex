defmodule PregelExTest do
  use ExUnit.Case
  alias PregelEx.Builder, as: Builder
  doctest PregelEx

  setup do
    # Clean up any existing children before each test
    PregelEx.GraphSupervisor.stop_all_graphs()

    # Register cleanup for after the test completes
    on_exit(fn ->
      PregelEx.GraphSupervisor.stop_all_graphs()
    end)

    :ok
  end

  @doc """
  Tests the creation of a basic graph using `PregelEx.create_graph/1`.

  This test verifies that:
  - The `PregelEx.GraphSupervisor` initially has no children.
  - A new graph can be created with a given name ("graph_a").
  - The returned process identifier (`pid`) is a valid PID.
  - The returned `graph_id` is a binary.
  - After creation, the supervisor has exactly one child process.
  """
  test "001 create basic graph" do
    assert [] = Supervisor.which_children(PregelEx.GraphSupervisor)
    {:ok, graph_id, pid} = PregelEx.create_graph("graph_a")
    assert is_pid(pid)
    assert is_binary(graph_id)
    assert length(Supervisor.which_children(PregelEx.GraphSupervisor)) == 1
  end

  @doc """
  Tests the creation of multiple graphs using `PregelEx.create_graph/1`.

  This test verifies that:
  - The `PregelEx.GraphSupervisor` starts with no child processes.
  - Creating two graphs with different names returns valid PIDs and unique graph IDs.
  - Both returned PIDs are valid and distinct.
  - Both graph IDs are valid binaries and are not equal.
  - After creation, the supervisor has exactly two child processes.

  Ensures that multiple graphs can be created independently and are properly supervised.
  """
  test "002 create multiple graphs" do
    assert [] = Supervisor.which_children(PregelEx.GraphSupervisor)
    {:ok, graph_id_a, pid_a} = PregelEx.create_graph("graph_a")
    {:ok, graph_id_b, pid_b} = PregelEx.create_graph("graph_b")
    assert is_pid(pid_a)
    assert is_pid(pid_b)
    assert is_binary(graph_id_a)
    assert is_binary(graph_id_b)
    assert length(Supervisor.which_children(PregelEx.GraphSupervisor)) == 2
    assert graph_id_a != graph_id_b
    assert pid_a != pid_b
  end

  @doc """
  Tests the creation of a graph with a single vertex using `PregelEx.create_vertex/3`.

  This test verifies that:
  - A graph can be created successfully.
  - A vertex can be added to the graph with a name and computation function.
  - The vertex is assigned a unique binary ID and valid PID.
  - The vertex state is properly initialized with correct default values.
  - The vertex's computation function behaves as expected (returns `:ok` for any input).
  - Function behavior can be tested independently of function reference equality.

  This test demonstrates the fundamental vertex creation functionality of the Pregel framework.
  """
  test "003 create graph with vertex" do
    assert [] = Supervisor.which_children(PregelEx.GraphSupervisor)
    {:ok, graph_id, pid} = PregelEx.create_graph("graph_with_vertices")
    assert is_pid(pid)
    assert is_binary(graph_id)
    assert length(Supervisor.which_children(PregelEx.GraphSupervisor)) == 1
    function = fn _ -> :ok end

    {:ok, vertex_id, vertex_pid, _} =
      PregelEx.create_vertex(graph_id, "vertex_1", function, type: :source)

    assert is_binary(vertex_id)
    assert is_pid(vertex_pid)

    {:ok, vertex_state} = PregelEx.get_vertex_state(graph_id, vertex_id)

    # Test each field individually, comparing function behavior instead of reference
    assert vertex_state.graph_id == graph_id
    assert vertex_state.id == vertex_id
    assert vertex_state.name == "vertex_1"
    assert vertex_state.value == nil
    assert vertex_state.active == true
    assert vertex_state.outgoing_edges == %{}

    # Test that the function behaves the same way
    assert vertex_state.function.(nil) == function.(nil)
  end

  @doc """
  Tests the creation of a graph with multiple vertices.

  This test will verify that:
  - Multiple vertices can be created within a single graph.
  - Each vertex maintains its own unique identity and state.
  - Vertices can have different computation functions.
  - The graph properly manages multiple vertex processes.
  """
  test "004 create graph with vertexes" do
    # Setup graph
    assert [] = Supervisor.which_children(PregelEx.GraphSupervisor)
    {:ok, graph_id, pid} = PregelEx.create_graph("graph_with_vertices")
    assert is_pid(pid)
    assert is_binary(graph_id)
    assert length(Supervisor.which_children(PregelEx.GraphSupervisor)) == 1

    # Add first vertex
    function_1 = fn _ -> {:ok, 1} end

    {:ok, vertex_id_1, vertex_pid_1, _} =
      PregelEx.create_vertex(graph_id, "vertex_1", function_1, type: :source)

    assert is_binary(vertex_id_1)
    assert is_pid(vertex_pid_1)

    {:ok, vertex_state_1} = PregelEx.get_vertex_state(graph_id, vertex_id_1)

    ## Test each field individually, comparing function behavior instead of reference
    assert vertex_state_1.graph_id == graph_id
    assert vertex_state_1.id == vertex_id_1
    assert vertex_state_1.name == "vertex_1"
    assert vertex_state_1.value == nil
    assert vertex_state_1.active == true
    assert vertex_state_1.outgoing_edges == %{}

    ## Test that the function behaves the same way
    assert vertex_state_1.function.(nil) == function_1.(nil)

    # Add second vertex
    function_2 = fn _ -> {:ok, 2} end

    {:ok, vertex_id_2, vertex_pid_2, _} =
      PregelEx.create_vertex(graph_id, "vertex_2", function_2, type: :source)

    assert is_binary(vertex_id_2)
    assert is_pid(vertex_pid_2)

    {:ok, vertex_state_2} = PregelEx.get_vertex_state(graph_id, vertex_id_2)

    ## Test each field individually, comparing function behavior instead of reference
    assert vertex_state_2.graph_id == graph_id
    assert vertex_state_2.id == vertex_id_2
    assert vertex_state_2.name == "vertex_2"
    assert vertex_state_2.value == nil
    assert vertex_state_2.active == true
    assert vertex_state_2.outgoing_edges == %{}

    ## Test that the function behaves the same way
    assert vertex_state_2.function.(nil) == function_2.(nil)

    # Verify that both vertices are registered in the graph
    {:ok, vertices} = PregelEx.list_vertices(graph_id)
    assert length(vertices) == 2
    {:ok, _} = PregelEx.get_vertex_state(graph_id, vertex_id_1)
    {:ok, _} = PregelEx.get_vertex_state(graph_id, vertex_id_2)

    ## Compute each vertex in the graph
    {:ok, {:ok, 1}, _messages} = PregelEx.compute_vertex(graph_id, vertex_id_1)
    {:ok, {:ok, 2}, _messages} = PregelEx.compute_vertex(graph_id, vertex_id_2)
  end

  @doc """
  Tests the creation of multiple graphs, each with their own set of vertices, and verifies their independent state.

  This test performs the following steps:
    * Asserts that there are no child graphs initially under the `PregelEx.GraphSupervisor`.
    * Creates two separate graphs (`graph_a` and `graph_b`).
    * Adds two vertices to each graph, each with a unique label and initialization function.
    * Computes each vertex and asserts that the computation returns the expected result for each vertex.
    * Verifies that each graph contains exactly two vertices.

  This ensures that:
    * Multiple graphs can be created and managed independently.
    * Vertices are correctly associated with their respective graphs.
    * Vertex computation and counting functions operate correctly per graph.
  """
  test "005 create multiple graphs with vertexes" do
    assert [] = Supervisor.which_children(PregelEx.GraphSupervisor)
    {:ok, graph_id_a, _} = PregelEx.create_graph("graph_a")
    {:ok, graph_id_b, _} = PregelEx.create_graph("graph_b")

    # Graph A vertices
    {
      :ok,
      v1_id,
      _,
      _
    } =
      PregelEx.create_vertex(graph_id_a, "vertex_1", fn _ -> %{result: 1} end, type: :source)

    {
      :ok,
      v2_id,
      _,
      _
    } =
      PregelEx.create_vertex(graph_id_a, "vertex_2", fn _ -> %{result: 2} end, type: :source)

    # Graph B vertices
    {
      :ok,
      v3_id,
      _,
      _
    } =
      PregelEx.create_vertex(graph_id_b, "vertex_3", fn _ -> %{result: 3} end, type: :source)

    {
      :ok,
      v4_id,
      _,
      _
    } =
      PregelEx.create_vertex(graph_id_b, "vertex_4", fn _ -> %{result: 4} end, type: :source)

    # Verify results of both graph's vertices
    {:ok, %{result: 1}, _messages} = PregelEx.compute_vertex(graph_id_a, v1_id)
    {:ok, %{result: 2}, _messages} = PregelEx.compute_vertex(graph_id_a, v2_id)
    {:ok, %{result: 3}, _messages} = PregelEx.compute_vertex(graph_id_b, v3_id)
    {:ok, %{result: 4}, _messages} = PregelEx.compute_vertex(graph_id_b, v4_id)

    # Verify that both graphs have the correct number of vertices
    assert 2 = PregelEx.get_vertex_count(graph_id_a)
    assert 2 = PregelEx.get_vertex_count(graph_id_b)
  end

  @doc """
  Tests edge creation and management between vertices.

  This test verifies that:
  - Edges can be created between existing vertices in a graph.
  - Edges contain proper source/destination vertex IDs and weights.
  - Vertices maintain their outgoing edges in their state.
  - Edge removal works correctly.
  - Edge listing functionality works for the entire graph.
  """
  test "006 create and manage edges" do
    assert [] = Supervisor.which_children(PregelEx.GraphSupervisor)
    {:ok, graph_id, _pid} = PregelEx.create_graph("graph_with_edges")

    # Create three vertices
    function = fn x -> x + 1 end
    {:ok, vertex_id_1, _, _} = PregelEx.create_vertex(graph_id, "vertex_1", function)
    {:ok, vertex_id_2, _, _} = PregelEx.create_vertex(graph_id, "vertex_2", function)
    {:ok, vertex_id_3, _, _} = PregelEx.create_vertex(graph_id, "vertex_3", function)

    # Create edges: 1 -> 2 (weight 1.5), 1 -> 3 (weight 2.0), 2 -> 3 (weight 0.5)
    {:ok, edge_1_2} = PregelEx.create_edge(graph_id, vertex_id_1, vertex_id_2, 1.5)
    {:ok, _edge_1_3} = PregelEx.create_edge(graph_id, vertex_id_1, vertex_id_3, 2.0)
    {:ok, _edge_2_3} = PregelEx.create_edge(graph_id, vertex_id_2, vertex_id_3, 0.5)

    # Verify edge structure
    assert edge_1_2.from_vertex_id == vertex_id_1
    assert edge_1_2.to_vertex_id == vertex_id_2
    assert edge_1_2.weight == 1.5
    assert edge_1_2.properties == %{}

    # Test vertex neighbors
    {:ok, neighbors_1} = PregelEx.get_vertex_neighbors(graph_id, vertex_id_1)
    {:ok, neighbors_2} = PregelEx.get_vertex_neighbors(graph_id, vertex_id_2)
    {:ok, neighbors_3} = PregelEx.get_vertex_neighbors(graph_id, vertex_id_3)

    assert length(neighbors_1) == 2
    assert vertex_id_2 in neighbors_1
    assert vertex_id_3 in neighbors_1
    assert length(neighbors_2) == 1
    assert vertex_id_3 in neighbors_2
    assert length(neighbors_3) == 0

    # Test outgoing edges for vertex 1
    {:ok, edges_1} = PregelEx.get_vertex_edges(graph_id, vertex_id_1)
    assert length(edges_1) == 2

    # Test graph-wide edge listing
    {:ok, all_edges} = PregelEx.list_edges(graph_id)
    assert length(all_edges) == 3

    # Test edge removal
    {:ok, removed_edge} = PregelEx.remove_edge(graph_id, vertex_id_1, vertex_id_2)
    assert removed_edge.to_vertex_id == vertex_id_2

    # Verify edge was removed
    {:ok, neighbors_1_after} = PregelEx.get_vertex_neighbors(graph_id, vertex_id_1)
    assert length(neighbors_1_after) == 1
    assert vertex_id_2 not in neighbors_1_after
    assert vertex_id_3 in neighbors_1_after

    {:ok, all_edges_after} = PregelEx.list_edges(graph_id)
    assert length(all_edges_after) == 2
  end

  test "007 sent message between vertices" do
    assert [] = Supervisor.which_children(PregelEx.GraphSupervisor)
    {:ok, graph_id, _pid} = PregelEx.create_graph("graph_with_messages")

    # Create two vertices
    function = fn _ -> :ok end
    {:ok, vertex_id_1, _, _} = PregelEx.create_vertex(graph_id, "vertex_1", function)
    {:ok, vertex_id_2, _, _} = PregelEx.create_vertex(graph_id, "vertex_2", function)

    # Send message from vertex 1 to vertex 2
    message = "Howdy World!"
    PregelEx.send_message(graph_id, vertex_id_1, vertex_id_2, message)

    # Verify message is queued
    {:ok, vertex_state_1} = PregelEx.get_vertex_state(graph_id, vertex_id_1)
    assert length(vertex_state_1.outgoing_messages) == 1
    assert vertex_state_1.outgoing_messages |> hd() |> Map.get(:content) == message

    # Execute superstep (routes messages)
    PregelEx.execute_superstep(graph_id)

    # Verify message was delivered
    {:ok, vertex_state_2} = PregelEx.get_vertex_state(graph_id, vertex_id_2)
    assert length(vertex_state_2.incoming_messages) == 1
    assert vertex_state_2.incoming_messages |> hd() |> Map.get(:content) == message

    # Verify vertex 1 has no outgoing messages after superstep
    {:ok, vertex_state_1} = PregelEx.get_vertex_state(graph_id, vertex_id_1)
    assert length(vertex_state_1.outgoing_messages) == 0
  end

  test "test 008 single source shortest path" do
    assert [] = Supervisor.which_children(PregelEx.GraphSupervisor)
    {:ok, graph_id, _pid} = PregelEx.create_graph("graph_shortest_path")

    # Create vertices
    # NOTE: this is not sending the message I believe, there is no notion of sending an outgoing message in this function
    # Question: should the return value always be the sending message or something like this?
    # Coming back the next day ...
    # The question is what should these functions return?
    # If they return just a value, how does that value get sent to other vertices?
    # If they return a message, how does that message get sent to other vertices?
    # If they return a list of messages, how does that get sent to other vertices?
    function = fn _ -> :ok end
    {:ok, v1_id, _, _} = PregelEx.create_vertex(graph_id, "v1", function)
    {:ok, v2_id, _, _} = PregelEx.create_vertex(graph_id, "v2", function)
    {:ok, v3_id, _, _} = PregelEx.create_vertex(graph_id, "v3", function)

    # Create edges
    PregelEx.create_edge(graph_id, v1_id, v2_id, 1)
    PregelEx.create_edge(graph_id, v2_id, v3_id, 1)
    PregelEx.create_edge(graph_id, v1_id, v3_id, 5)

    # Send message from v1 to v3
    PregelEx.send_message(graph_id, v1_id, v3_id, :find_shortest_path)

    # Execute superstep
    PregelEx.execute_superstep(graph_id)

    # Verify shortest path found
    {:ok, vertex_state_v3} = PregelEx.get_vertex_state(graph_id, v3_id)
    assert length(vertex_state_v3.incoming_messages) == 1
  end

  test "009 test simple 3 part graph" do
    assert [] = Supervisor.which_children(PregelEx.GraphSupervisor)

    add_one = fn context ->
      case context.aggregated_messages do
        nil -> %{sum: 1}
        %{sum: sum} -> %{sum: sum + 1}
      end
    end

    # Create graph
    {:ok, graph_id, _} = PregelEx.create_graph("sum_graph")

    # Create vertices
    {:ok, start_vertex_id, _, _} =
      PregelEx.create_vertex(
        graph_id,
        "start",
        fn _ -> %{sum: 0} end,
        type: :source
      )

    {:ok, vertex_1, _, _} = PregelEx.create_vertex(graph_id, "v1", add_one)
    {:ok, vertex_2, _, _} = PregelEx.create_vertex(graph_id, "v2", add_one)

    {:ok, final_vertex_id, _, _} =
      PregelEx.create_vertex(
        graph_id,
        "final",
        fn context -> context.aggregated_messages end,
        type: :final
      )

    # Create edges
    PregelEx.create_edge(graph_id, start_vertex_id, vertex_1)
    PregelEx.create_edge(graph_id, vertex_1, vertex_2)
    PregelEx.create_edge(graph_id, vertex_2, final_vertex_id)

    {:ok, info} = PregelEx.run(graph_id)
    {:ok, final} = PregelEx.get_final_value(graph_id)

    assert final.value == %{sum: 2}
  end

  test "010 builder api" do
    """
    This test is a copy of 009 except it attempts to use the builder pattern
    to create a graph
    """

    assert [] = Supervisor.which_children(PregelEx.GraphSupervisor)

    add_one = fn context ->
      case context.aggregated_messages do
        nil -> %{sum: 1}
        %{sum: sum} -> %{sum: sum + 1}
      end
    end

    {:ok, graph_id, _graph_pid} =
      Builder.build("sum_graph")
      |> Builder.add_vertex(
        "start",
        fn _ -> %{sum: 0} end,
        type: :source
      )
      |> Builder.add_vertex("v1", add_one)
      |> Builder.add_vertex("v2", add_one)
      |> Builder.add_vertex(
        "end",
        fn context -> context.aggregated_messages end,
        type: :final
      )
      |> Builder.add_edge("start", "v1")
      |> Builder.add_edge("v1", "v2")
      |> Builder.add_edge("v2", "end")
      |> Builder.finish()

    {:ok, info} = PregelEx.run(graph_id)
    {:ok, final} = PregelEx.get_final_value(graph_id)

    assert final.value == %{sum: 2}
  end
end
