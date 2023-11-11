defmodule Topical.Adapters.Plug.WebSockServer do
  @moduledoc """
  A WebSocket server for a WebSock service (for use with Plug).

  ## Options

   - `registry` - The name of the Topical registry. Required.
   - `init` - A function called before upgrading the connection, which is passed the request. The
     function must return `{:ok, context}` for the connection to be accepted. This `context` is then
     passed to topics.

  ## Example

      defmodule Router do
        use Plug.Router

        plug :match
        plug :dispatch

        # ...

        get "/socket" do
          conn
          |> WebSockAdapter.upgrade(
            Topical.Adapters.Plug.WebSockServer,
            [registry: MyRegistry],
            timeout: 60_000)
          |> halt()
        end

        # ...
      end
  """

  alias Topical.Adapters.Base.WebSocket, as: Base

  def init(opts) do
    conn = Keyword.get(opts, :conn)

    case Base.init(opts, conn) do
      {:ok, state} ->
        {:ok, state}
    end
  end

  def handle_in({text, [opcode: :text]}, state) do
    case Base.handle_text(text, state) do
      {:ok, messages, state} ->
        {:push, Enum.map(messages, &{:text, &1}), state}
    end
  end

  def handle_info(info, state) do
    case Base.handle_info(info, state) do
      {:ok, messages, state} ->
        {:push, Enum.map(messages, &{:text, &1}), state}
    end
  end
end
