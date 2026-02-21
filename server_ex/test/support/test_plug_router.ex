defmodule Topical.Test.PlugRouter do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/socket" do
    opts = conn.private[:topical_opts] || []
    registry = Keyword.fetch!(opts, :registry)
    init_fn = Keyword.get(opts, :init)

    ws_opts = [registry: registry] ++ if(init_fn, do: [init: init_fn], else: [])

    conn
    |> WebSockAdapter.upgrade(Topical.Adapters.Plug.WebSockServer, ws_opts, timeout: 60_000)
    |> halt()
  end

  get "/topics/*topic" do
    opts = conn.private[:topical_opts] || []
    registry = Keyword.fetch!(opts, :registry)
    init_fn = Keyword.get(opts, :init)
    context = if init_fn, do: init_fn.(conn) |> elem(1), else: nil

    case Topical.capture(registry, topic, context) do
      {:ok, value} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(value))

      {:error, :not_found} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{"error" => "not_found"}))

      {:error, :unauthorized} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(403, Jason.encode!(%{"error" => "unauthorized"}))

      {:error, error} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{"error" => error}))
    end
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
