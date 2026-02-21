defmodule Topical.Test.WebSocketTestHelper do
  @moduledoc false

  @all_topics [
    Topical.Test.CounterTopic,
    Topical.Test.AuthorizedTopic,
    Topical.Test.CallbackTopic,
    Topical.Test.FailingTopic,
    Topical.Test.ListTopic,
    Topical.Test.MergeTopic,
    Topical.Test.LeaderboardTopic,
    Topical.Test.DocumentTopic
  ]

  @doc """
  Starts a Topical registry and HTTP server on a random port.
  Returns %{port: port, registry: registry_name}.
  """
  def start_server(adapter, opts \\ []) do
    init_fn = Keyword.get(opts, :init)
    registry_name = :"ws_test_registry_#{System.unique_integer([:positive])}"

    ExUnit.Callbacks.start_supervised!(%{
      id: registry_name,
      start:
        {Topical.Registry, :start_link,
         [[name: registry_name, topics: @all_topics]]}
    })

    port =
      case adapter do
        :cowboy -> start_cowboy(registry_name, init_fn)
        :bandit -> start_bandit(registry_name, init_fn)
      end

    %{port: port, registry: registry_name}
  end

  defp start_cowboy(registry, init_fn) do
    alias Topical.Adapters.Cowboy.WebsocketHandler

    ws_opts = [registry: registry] ++ if(init_fn, do: [init: init_fn], else: [])

    alias Topical.Adapters.Cowboy.RestHandler
    rest_opts = [registry: registry] ++ if(init_fn, do: [init: init_fn], else: [])

    dispatch =
      :cowboy_router.compile([
        {:_,
         [
           {"/socket", WebsocketHandler, ws_opts},
           {"/topics/[...]", RestHandler, rest_opts}
         ]}
      ])

    ref = :"cowboy_ws_test_#{System.unique_integer([:positive])}"
    trans_opts = %{socket_opts: [port: 0]}
    proto_opts = %{env: %{dispatch: dispatch}, connection_type: :supervisor}

    # Ranch returns old-format tuple child specs; convert to map for start_supervised!
    {id, start, restart, shutdown, type, modules} =
      :ranch.child_spec(ref, :ranch_tcp, trans_opts, :cowboy_clear, proto_opts)

    ExUnit.Callbacks.start_supervised!(%{
      id: id,
      start: start,
      restart: restart,
      shutdown: shutdown,
      type: type,
      modules: modules
    })

    :ranch.get_port(ref)
  end

  defp start_bandit(registry, init_fn) do
    plug_opts = [registry: registry] ++ if(init_fn, do: [init: init_fn], else: [])

    bandit =
      ExUnit.Callbacks.start_supervised!(
        {Bandit, plug: {Topical.Test.PlugRouter, plug_opts}, port: 0, startup_log: false}
      )

    {:ok, {_addr, port}} = ThousandIsland.listener_info(bandit)
    port
  end

  @doc """
  Opens a Gun WebSocket connection. Returns %{conn: pid, stream_ref: ref}.
  """
  def ws_connect(port) do
    {:ok, conn} = :gun.open(~c"localhost", port, %{protocols: [:http]})
    {:ok, :http} = :gun.await_up(conn, 5_000)
    stream_ref = :gun.ws_upgrade(conn, ~c"/socket")

    receive do
      {:gun_upgrade, ^conn, ^stream_ref, ["websocket"], _headers} ->
        %{conn: conn, stream_ref: stream_ref}
    after
      5_000 -> raise "WebSocket upgrade timed out"
    end
  end

  @doc """
  JSON-encodes and sends a WebSocket text frame.
  """
  def ws_send(%{conn: conn, stream_ref: stream_ref} = _ws, message) do
    :gun.ws_send(conn, stream_ref, {:text, Jason.encode!(message)})
  end

  @doc """
  Receives and JSON-decodes the next WebSocket text frame.
  """
  def ws_receive(%{conn: conn, stream_ref: stream_ref} = _ws, timeout \\ 5_000) do
    receive do
      {:gun_ws, ^conn, ^stream_ref, {:text, text}} ->
        Jason.decode!(text)
    after
      timeout -> raise "No WebSocket message received within #{timeout}ms"
    end
  end

  @doc """
  Receives N WebSocket messages.
  """
  def ws_receive_all(ws, count) do
    Enum.map(1..count, fn _ -> ws_receive(ws) end)
  end

  @doc """
  Asserts no WebSocket message arrives within the timeout.
  """
  def ws_refute_receive(%{conn: conn, stream_ref: stream_ref} = _ws, timeout \\ 200) do
    receive do
      {:gun_ws, ^conn, ^stream_ref, {:text, text}} ->
        raise "Expected no WebSocket message, but received: #{text}"
    after
      timeout -> :ok
    end
  end

  @doc """
  Closes the WebSocket connection.
  """
  def ws_close(%{conn: conn} = _ws) do
    :gun.close(conn)
  end

  @doc """
  Makes an HTTP GET request to the capture endpoint. Returns {status, body}.
  """
  def http_get(port, path) do
    {:ok, conn} = :gun.open(~c"localhost", port, %{protocols: [:http]})
    {:ok, :http} = :gun.await_up(conn, 5_000)
    stream_ref = :gun.get(conn, String.to_charlist(path))
    {:response, :nofin, status, _headers} = :gun.await(conn, stream_ref, 5_000)
    {:ok, body} = :gun.await_body(conn, stream_ref, 5_000)
    :gun.close(conn)
    {status, Jason.decode!(body)}
  end

  # Protocol message builders

  def subscribe_msg(channel_id, topic, params \\ nil) do
    if params do
      [2, channel_id, topic, params]
    else
      [2, channel_id, topic]
    end
  end

  def unsubscribe_msg(channel_id) do
    [3, channel_id]
  end

  def execute_msg(channel_id, topic, action, args, params \\ nil) do
    if params do
      [1, channel_id, topic, action, args, params]
    else
      [1, channel_id, topic, action, args]
    end
  end

  def notify_msg(topic, action, args, params \\ nil) do
    if params do
      [0, topic, action, args, params]
    else
      [0, topic, action, args]
    end
  end
end
