defmodule PregelExTest do
  use ExUnit.Case
  doctest PregelEx

  test "create vertex in graph" do
    # ensure the graph supervisor is started with no children
    assert [] = Supervisor.which_children(PregelEx.Graph)

    # test creation of a vertex
    {:ok, vertex_id} = PregelEx.Graph.create_vertex("test_vertex", fn _ -> :ok end)
    assert is_binary(vertex_id)

    # test that the vertex is registered
    assert length(Supervisor.which_children(PregelEx.Graph)) == 1

    # test that vertex has a pid
    assert {:ok, pid} = PregelEx.Graph.get_vertex_pid(vertex_id)
    assert is_pid(pid)

    # test state of the vertex
    assert {:ok, state} = PregelEx.Graph.get_vertex_state(vertex_id)
    assert state.id == vertex_id
    assert state.name == "test_vertex"
    assert state.value == %{}
    assert state.state == :inactive
    assert state.neighbors == []

    # test functions evaluate to the same result
    func = fn _ -> :ok end
    assert state.function.(nil) == func.(nil)
  end
end
