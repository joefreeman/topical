defmodule Canvas.Application do
  @moduledoc false

  use Application

  alias Canvas.Topics

  @impl true
  def start(_type, _args) do
    port = 3000

    children = [
      {Topical, name: Canvas.Registry, topics: [Topics.CanvasTopic]},
      {Canvas.Web, port: port}
    ]

    opts = [strategy: :one_for_one, name: Canvas.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      IO.puts("Server running on port #{port}.")
      {:ok, pid}
    end
  end
end
