defmodule Topical.Adapters.Cowboy.WebsocketHandler do
  @moduledoc """
  A Websocket handler adapter for a Cowboy web server.

  ## Options

   - `registry` - The name of the Topical registry. Required.
   - `init` - A function called before upgrading the connection, passed the request. The function
     must return `{:ok, context}` for the connection to be accepted. This `context` is then passed
     to topics.

  ## Example

      :cowboy_router.compile([
        {:_,
         [
           # ...
           {"/socket", WebsocketHandler, registry: MyApp.Topical}
         ]}
      ])
  """
  alias Topical.Protocol.{Request, Response}

  @doc false
  def init(req, opts) do
    registry = Keyword.fetch!(opts, :registry)
    init = Keyword.get(opts, :init)
    result = if init, do: init.(req), else: {:ok, nil}

    case result do
      {:ok, context} ->
        {:cowboy_websocket, req, {registry, context}}
    end
  end

  @doc false
  def websocket_init({registry, context}) do
    state = %{
      registry: registry,
      context: context,
      channels: %{},
      channel_ids: %{}
    }

    {[], state}
  end

  @doc false
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

  @doc false
  def websocket_handle(_data, state) do
    {[], state}
  end

  @doc false
  def websocket_info({:reset, ref, value}, state) do
    case Map.fetch(state.channel_ids, ref) do
      {:ok, channel_id} ->
        {[{:text, Response.encode_topic_reset(channel_id, value)}], state}

      :error ->
        {[], state}
    end
  end

  @doc false
  def websocket_info({:updates, ref, updates}, state) do
    case Map.fetch(state.channel_ids, ref) do
      {:ok, channel_id} ->
        {[
           {:text, Response.encode_topic_updates(channel_id, updates)}
         ], state}

      :error ->
        {[], state}
    end
  end

  @doc false
  def websocket_info(_info, state) do
    {[], state}
  end

  @doc false
  def handle_notify(topic, action, args, state) do
    # TODO: handle some errors (e.g., with lookup/init topic?)
    case Topical.notify(state.registry, topic, action, List.to_tuple(args), state.context) do
      :ok ->
        {[], state}
    end
  end

  defp handle_execute(channel_id, topic, action, args, state) do
    # TODO: don't block?
    case Topical.execute(state.registry, topic, action, List.to_tuple(args), state.context) do
      {:ok, result} ->
        {[{:text, Response.encode_result(channel_id, result)}], state}

      {:error, error} ->
        {[{:text, Response.encode_error(channel_id, error)}], state}
    end
  end

  defp handle_subscribe(channel_id, topic, state) do
    case Topical.subscribe(state.registry, topic, self(), state.context) do
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

  defp handle_unsubscribe(channel_id, state) do
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
