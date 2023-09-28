defmodule EventSourcing.AccountTopic do
  use Topical.Topic, route: "accounts/:account_id"

  alias EventSourcing.Ledger

  @ledger EventSourcing.Ledger
  @latest_transactions_limit 10

  def init(params) do
    account_id = Keyword.fetch!(params, :account_id)

    {:ok, ref, transactions} = Ledger.subscribe(@ledger, account_id, self())
    account = build_account(transactions, account_id)

    last_transaction = List.last(transactions)
    last_transaction_id = if last_transaction, do: last_transaction.id

    {:ok,
     Topic.new(account, %{
       ref: ref,
       account_id: account_id,
       last_transaction_id: last_transaction_id
     })}
  end

  def handle_info({:transaction, transaction}, topic) do
    new_balance = update_balance(topic.value.balance, transaction, topic.state.account_id)
    topic = put_in(topic.state.last_transaction_id, transaction.id)
    topic = Topic.set(topic, [:balance], new_balance)
    # TODO: limit number of transactions
    topic = Topic.insert(topic, [:latest_transactions], transaction)
    {:ok, topic}
  end

  def handle_execute("transfer", {to_account_id, amount}, topic, _context) do
    # TODO: check balance
    {:ok, _} =
      Ledger.transfer(
        @ledger,
        topic.state.ref,
        to_account_id,
        amount,
        topic.state.last_transaction_id
      )

    {:ok, true, topic}
  end

  defp build_account(transactions, account_id) do
    latest_transactions =
      transactions
      |> Enum.take(-@latest_transactions_limit)
      |> Enum.map(&Map.from_struct/1)

    balance = Enum.reduce(transactions, 0, &update_balance(&2, &1, account_id))
    %{latest_transactions: latest_transactions, balance: balance}
  end

  defp update_balance(balance, transaction, account_id) do
    balance =
      if transaction.from_account_id == account_id do
        balance - transaction.amount
      else
        balance
      end

    balance =
      if transaction.to_account_id == account_id do
        balance + transaction.amount
      else
        balance
      end

    balance
  end
end
