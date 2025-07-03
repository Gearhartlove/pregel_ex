# PregelEx

PregelEx - A distributed graph processing framework in Elixir

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `pregel_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pregel_ex, "~> 0.1.0"}
  ]
end
```

## Example 
```elixir
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
{:ok, start_vertex_id, _} =
  PregelEx.create_vertex(
    graph_id,
    "start",
    fn _ -> %{sum: 0} end,
    type: :source
  )

{:ok, vertex_1, _} = PregelEx.create_vertex(graph_id, "v1", add_one)
{:ok, vertex_2, _} = PregelEx.create_vertex(graph_id, "v2", add_one)

{:ok, final_vertex_id, _} =
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

# Run the graph
:ok = PregelEx.run(graph_id)
{:ok, final} = PregelEx.get_final_value(graph_id)

assert final.value == %{sum: 2}
```

