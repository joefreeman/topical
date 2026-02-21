defmodule Topical.Test.PlugRouter do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/socket" do
    opts = conn.private[:topical_opts] || []
    registry = Keyword.fetch!(opts, :registry)
    init_fn = Keyword.get(opts, :init)

    ws_opts = [registry: registry] ++ if(init_fn, do: [init: init_fn], else: [])

    conn
    |> WebSockAdapter.upgrade(Topical.Adapters.Plug.WebSockServer, ws_opts, timeout: 60_000)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  def call(conn, opts) do
    conn
    |> Plug.Conn.put_private(:topical_opts, opts)
    |> super(opts)
  end
end
