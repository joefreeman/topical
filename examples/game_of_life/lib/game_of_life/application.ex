defmodule GameOfLife.Application do
  use Application

  @impl true
  def start(_type, _args) do
    port = 3000

    children = [
      {Topical, name: GameOfLife.Registry, topics: [GameOfLife.GameTopic]},
      {GameOfLife.Web, port: port}
    ]

    opts = [strategy: :one_for_one, name: GameOfLife.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
