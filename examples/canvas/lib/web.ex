defmodule Canvas.Web do
  @otp_app Mix.Project.config()[:app]

  alias Topical.Adapters.Cowboy.WebsocketHandler

  def child_spec(opts) do
    port = Keyword.fetch!(opts, :port)
    trans_opts = %{socket_opts: [port: port]}
    proto_opts = %{env: %{dispatch: dispatch()}, connection_type: :supervisor}
    :ranch.child_spec(:http, :ranch_tcp, trans_opts, :cowboy_clear, proto_opts)
  end

  defp dispatch() do
    :cowboy_router.compile([
      {:_,
       [
         {"/", :cowboy_static, {:priv_file, @otp_app, "static/index.html"}},
         {"/assets/[...]", :cowboy_static, {:priv_dir, @otp_app, "static/assets"}},
         {"/socket", WebsocketHandler, registry: Canvas.Registry, init: &socket_init/1}
       ]}
    ])
  end

  defp socket_init(req) do
    qs = :cowboy_req.parse_qs(req)

    case List.keyfind(qs, "client", 0) do
      {"client", client_id} ->
        {:ok, %{client_id: client_id}}

      nil ->
        {:error, :no_client_id}
    end
  end
end
