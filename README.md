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
  alias PregelEx.Builder, as: Builder

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
```

