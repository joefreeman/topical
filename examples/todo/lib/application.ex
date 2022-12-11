defmodule Todo.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Topical, name: Todo.Registry, topics: [Todo.ListTopic]}
    ]

    opts = [strategy: :one_for_one, name: Todo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
