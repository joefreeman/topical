defmodule Todo.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    cowboy_port = 3001
    bandit_port = 3002

    children = [
      {Topical, name: Todo.Registry, topics: [Todo.ListsTopic, Todo.ListTopic]},
      {Todo.CowboyServer, port: cowboy_port},
      {Bandit, plug: Todo.PlugRouter, scheme: :http, port: bandit_port}
    ]

    opts = [strategy: :one_for_one, name: Todo.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      IO.puts("Cowboy server on port #{cowboy_port}; Bandit server on port #{bandit_port}.")
      {:ok, pid}
    end
  end
end
