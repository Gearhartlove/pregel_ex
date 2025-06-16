# Edge Creation Example

# This example demonstrates the edge functionality in PregelEx
# Run this with: iex -S mix

alias PregelEx

# Create a graph
{:ok, _pid, graph_id} = PregelEx.create_graph("social_network")

# Create some vertices (people in a social network)
{:ok, alice_id, _} = PregelEx.create_vertex(graph_id, "alice", fn _ -> "Hello from Alice!" end)
{:ok, bob_id, _} = PregelEx.create_vertex(graph_id, "bob", fn _ -> "Hello from Bob!" end)
{:ok, charlie_id, _} = PregelEx.create_vertex(graph_id, "charlie", fn _ -> "Hello from Charlie!" end)

# Create friendships (edges) with different strength weights
{:ok, _edge1} = PregelEx.create_edge(graph_id, alice_id, bob_id, 0.8, %{type: "friendship"})
{:ok, _edge2} = PregelEx.create_edge(graph_id, alice_id, charlie_id, 0.6, %{type: "friendship"})
{:ok, _edge3} = PregelEx.create_edge(graph_id, bob_id, charlie_id, 0.9, %{type: "friendship"})

# Check Alice's friends
{:ok, alice_friends} = PregelEx.get_vertex_neighbors(graph_id, alice_id)
IO.puts("Alice's friends: #{inspect(alice_friends)}")

# Check all edges in the graph
{:ok, all_edges} = PregelEx.list_edges(graph_id)
IO.puts("All friendships in the network:")
Enum.each(all_edges, fn edge ->
  IO.puts("  #{edge.from_vertex_id} -> #{edge.to_vertex_id} (strength: #{edge.weight})")
end)

# Remove a friendship
{:ok, _removed_edge} = PregelEx.remove_edge(graph_id, alice_id, bob_id)

# Check Alice's friends again
{:ok, alice_friends_after} = PregelEx.get_vertex_neighbors(graph_id, alice_id)
IO.puts("Alice's friends after removing Bob: #{inspect(alice_friends_after)}")
