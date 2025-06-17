defmodule PregelEx.Message do
  @moduledoc """
  Represents a message in the PregelEx system.
  Messages are used to communicate between vertices during supersteps.
  """

  defstruct [
    :from_vertex_id,
    :to_vertex_id,
    :content,
    :superstep,
    :timestamp
  ]

  @type t :: %__MODULE__{
          from_vertex_id: String.t(),
          to_vertex_id: String.t(),
          content: any(),
          superstep: non_neg_integer(),
          timestamp: DateTime.t()
        }

  def new(from_vertex_id, to_vertex_id, content, superstep) do
    %__MODULE__{
      from_vertex_id: from_vertex_id,
      to_vertex_id: to_vertex_id,
      content: content,
      superstep: superstep,
      timestamp: DateTime.utc_now()
    }
  end
end
