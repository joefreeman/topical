defmodule EventSourcing.Ledger.Transaction do
  defstruct [:id, :from_account_id, :to_account_id, :amount]
end
