defmodule EventSourcing.Ledger do
  alias EventSourcing.Ledger.Server

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  def start_link(options) do
    {path, options} = Keyword.pop!(options, :path)
    GenServer.start_link(Server, path, options)
  end

  def subscribe(server, account_id, pid) do
    GenServer.call(server, {:subscribe, account_id, pid})
  end

  def transfer(server, ref, to_account_id, amount, last_transaction_id) do
    GenServer.call(server, {:transfer, ref, to_account_id, amount, last_transaction_id})
  end

  def unsubscribe(server, ref) do
    GenServer.cast(server, {:unsubscribe, ref})
  end
end
