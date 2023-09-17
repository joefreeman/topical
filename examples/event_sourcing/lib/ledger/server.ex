defmodule EventSourcing.Ledger.Server do
  use GenServer

  alias EventSourcing.Ledger.Transaction

  defmodule Subscriber do
    defstruct [:pid, :account_id, :last_transaction_id]

    def new(pid, account_id, last_transaction_id) do
      %Subscriber{
        pid: pid,
        account_id: account_id,
        last_transaction_id: last_transaction_id
      }
    end
  end

  defmodule State do
    defstruct path: nil,
              # account_id -> {ref}
              subscriptions: %{},
              # ref -> Subscriber
              subscribers: %{}
  end

  def init(path) do
    {:ok, %State{path: path}}
  end

  def handle_call({:subscribe, account_id, pid}, _from, state) do
    ref = Process.monitor(pid)

    transactions = load_transactions(state, account_id)
    last_transaction = List.last(transactions)
    last_transaction_id = if last_transaction, do: last_transaction.id

    state =
      state
      |> update_in(
        [Access.key(:subscriptions), Access.key(account_id, MapSet.new())],
        &MapSet.put(&1, ref)
      )
      |> put_in(
        [Access.key(:subscribers), ref],
        Subscriber.new(pid, account_id, last_transaction_id)
      )

    {:reply, {:ok, ref, transactions}, state}
  end

  def handle_call({:transfer, ref, to_account_id, amount, last_transaction_id}, _from, state) do
    subscriber = Map.fetch!(state.subscribers, ref)

    if last_transaction_id == subscriber.last_transaction_id do
      transaction = %Transaction{
        id: (last_transaction_id || 0) + 1,
        from_account_id: subscriber.account_id,
        to_account_id: to_account_id,
        amount: amount
      }

      record_transaction(state, transaction)
      state = notify_subscribers(state, transaction)
      {:reply, {:ok, transaction.id}, state}
    else
      {:reply, {:error, :invalid_transaction_id}, state}
    end
  end

  def handle_cast({:unsubscribe, ref}, _from, state) do
    Process.demonitor(ref)
    state = remove_subscriber(state, ref)
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    state = remove_subscriber(state, ref)
    {:noreply, state}
  end

  defp parse_line(line) do
    [event_id_s, from_account_id, to_account_id, amount_s] =
      line
      |> String.trim_trailing()
      |> String.split("\t")

    %Transaction{
      id: String.to_integer(event_id_s),
      from_account_id: from_account_id,
      to_account_id: to_account_id,
      amount: String.to_integer(amount_s)
    }
  end

  defp load_transactions(state, account_id) do
    if File.exists?(state.path) do
      state.path
      |> File.stream!()
      |> Stream.map(&parse_line/1)
      |> Stream.filter(fn transaction ->
        transaction.from_account_id == account_id or transaction.to_account_id == account_id
      end)
      |> Enum.to_list()
    else
      []
    end
  end

  defp record_transaction(state, transaction) do
    parts = [
      transaction.id,
      transaction.from_account_id,
      transaction.to_account_id,
      transaction.amount
    ]

    line = "#{Enum.join(parts, "\t")}\n"
    File.open!(state.path, [:append, :utf8], &IO.write(&1, line))
  end

  defp remove_subscriber(state, ref) do
    subscriber = Map.fetch!(state.subscribers, ref)
    account_id = subscriber.account_id

    state
    |> update_in([Access.key(:subscribers)], &Map.delete(&1, ref))
    |> Map.update!(:subscriptions, fn subscriptions ->
      refs = subscriptions |> Map.fetch!(account_id) |> MapSet.delete(ref)

      if Enum.empty?(refs) do
        Map.delete(subscriptions, account_id)
      else
        Map.put(subscriptions, account_id, refs)
      end
    end)
  end

  defp notify_subscribers(state, transaction) do
    Enum.reduce(
      [transaction.from_account_id, transaction.to_account_id],
      state,
      fn account_id, state ->
        state.subscriptions
        |> Map.get(account_id, MapSet.new())
        |> Enum.reduce(state, fn ref, state ->
          subscriber = Map.fetch!(state.subscribers, ref)
          send(subscriber.pid, {:transaction, transaction})

          if transaction.from_account_id == subscriber.account_id do
            put_in(state.subscribers[ref].last_transaction_id, transaction.id)
          else
            state
          end
        end)
      end
    )
  end
end
