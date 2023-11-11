defmodule Todo.PlugRouter do
  use Plug.Router

  alias Topical.Adapters.Plug.WebSockServer

  plug(Plug.Logger)
  plug(Plug.Static, from: "priv/static", at: "/")

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_header("location", "/index.html")
    |> send_resp(301, "index.html")
  end

  get "/socket" do
    conn
    |> WebSockAdapter.upgrade(WebSockServer, [registry: Todo.Registry], timeout: 60_000)
    |> halt()
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end
end
