defmodule Cache.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = 3000

    children = [
      {Topical, name: Cache.Registry, topics: [Cache.WidgetTopic]},
      {Cache.Web, port: port}
    ]

    opts = [strategy: :one_for_one, name: Cache.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      IO.puts("Server running on port #{port}.")
      {:ok, pid}
    end
  end
end
