defmodule Topical.Adapters.Cowboy.WebsocketHandler do
  alias Topical.Protocol.{Request, Response}

  def init(req, opts) do
    registry = Keyword.fetch!(opts, :registry)
    {:cowboy_websocket, req, registry}
  end

  def websocket_init(registry) do
    state = %{
      registry: registry,
      channels: %{},
      channel_ids: %{}
    }

    {[], state}
  end

  def websocket_handle({:text, text}, state) do
    case Request.decode(text) do
      {:ok, :notify, topic, action, args} ->
        handle_notify(topic, action, args, state)

      {:ok, :execute, channel_id, topic, action, args} ->
        handle_execute(channel_id, topic, action, args, state)

      {:ok, :subscribe, channel_id, topic} ->
        handle_subscribe(channel_id, topic, state)

      {:ok, :unsubscribe, channel_id} ->
        handle_unsubscribe(channel_id, state)
    end
  end

  def websocket_handle(_data, state) do
    {[], state}
  end

  def websocket_info({:reset, ref, value}, state) do
    channel_id = Map.fetch!(state.channel_ids, ref)
    {[{:text, Response.encode_topic_reset(channel_id, value)}], state}
  end

  def websocket_info({:updates, ref, updates}, state) do
    channel_id = Map.fetch!(state.channel_ids, ref)

    {[
       {:text, Response.encode_topic_updates(channel_id, updates)}
     ], state}
  end

  def websocket_info(_info, state) do
    {[], state}
  end

  def handle_notify(topic, action, args, state) do
    # TODO: handle some errors (e.g., with lookup/init topic?)
    case Topical.notify(state.registry, topic, action, List.to_tuple(args)) do
      :ok ->
        {[], state}
    end
  end

  defp handle_execute(channel_id, topic, action, args, state) do
    # TODO: don't block?
    case Topical.execute(state.registry, topic, action, List.to_tuple(args)) do
      {:ok, result} ->
        {[{:text, Response.encode_result(channel_id, result)}], state}

      {:error, error} ->
        {[{:text, Response.encode_error(channel_id, error)}], state}
    end
  end

  defp handle_subscribe(channel_id, topic, state) do
    case Topical.subscribe(state.registry, topic, self()) do
      {:ok, ref} ->
        state =
          state
          |> put_in([:channels, channel_id], {topic, ref})
          |> put_in([:channel_ids, ref], channel_id)

        {[], state}

      {:error, :not_found} ->
        {[{:text, Response.encode_error(channel_id, "not_found")}], state}
    end
  end

  def handle_unsubscribe(channel_id, state) do
    case Map.fetch(state.channels, channel_id) do
      {:ok, {topic, ref}} ->
        :ok = Topical.unsubscribe(state.registry, topic, ref)

        state =
          state
          |> Map.update!(:channels, &Map.delete(&1, channel_id))
          |> Map.update!(:channel_ids, &Map.delete(&1, ref))

        {[], state}
    end
  end
end
