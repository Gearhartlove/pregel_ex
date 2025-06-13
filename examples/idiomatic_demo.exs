# PregelEx Multi-Graph Example (Updated)

# Start two different graphs using the main module API
{:ok, _pid1, graph1_id} = PregelEx.create_graph("pagerank_graph")
{:ok, _pid2, graph2_id} = PregelEx.create_graph("shortest_path_graph")

IO.puts("Created graphs: #{graph1_id} and #{graph2_id}")
IO.puts("Total graphs: #{PregelEx.get_graph_count()}")

# Create vertices in the first graph
{:ok, v1_id, _pid} = PregelEx.create_vertex("pagerank_graph", "page_a", fn x -> x * 0.85 end, initial_value: 1.0)
{:ok, _v2_id, _pid} = PregelEx.create_vertex("pagerank_graph", "page_b", fn x -> x * 0.85 end, initial_value: 1.0)

# Create vertices in the second graph
{:ok, v3_id, _pid} = PregelEx.create_vertex("shortest_path_graph", "node_1", fn x -> x + 1 end, initial_value: 0)
{:ok, _v4_id, _pid} = PregelEx.create_vertex("shortest_path_graph", "node_2", fn x -> x + 1 end, initial_value: :infinity)

IO.puts("PageRank graph has #{PregelEx.get_vertex_count("pagerank_graph")} vertices")
IO.puts("Shortest Path graph has #{PregelEx.get_vertex_count("shortest_path_graph")} vertices")

# Get states of vertices in different graphs
state1 = PregelEx.get_vertex_state("pagerank_graph", v1_id)
state2 = PregelEx.get_vertex_state("shortest_path_graph", v3_id)

IO.puts("PageRank vertex state: #{inspect(state1)}")
IO.puts("Shortest Path vertex state: #{inspect(state2)}")
