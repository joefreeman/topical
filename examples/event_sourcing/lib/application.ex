defmodule EventSourcing.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = 3000

    children = [
      {EventSourcing.Ledger, path: "transactions.tsv", name: EventSourcing.Ledger},
      {Topical, name: EventSourcing.Registry, topics: [EventSourcing.AccountTopic]},
      {EventSourcing.Web, port: port}
    ]

    opts = [strategy: :one_for_one, name: EventSourcing.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      IO.puts("Server running on port #{port}.")
      {:ok, pid}
    end
  end
end
