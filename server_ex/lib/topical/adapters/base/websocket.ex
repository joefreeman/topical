defmodule Topical.Adapters.Base.WebSocket do
  @moduledoc false

  alias Topical.Protocol.{Request, Response}
  alias Topical.Registry

  def init(opts, init_arg \\ nil) do
    registry = Keyword.fetch!(opts, :registry)
    init = Keyword.get(opts, :init)
    result = if init, do: init.(init_arg), else: {:ok, nil}

    case result do
      {:ok, context} ->
        state = %{
          registry: registry,
          context: context,
          channels: %{},
          channel_ids: %{},
          # Maps normalized topic key -> channel_id for alias detection
          topic_keys: %{}
        }

        {:ok, state}
    end
  end

  def handle_text(text, state) do
    case Request.decode(text) do
      {:ok, :notify, topic, action, args, params} ->
        handle_notify(topic, action, args, params, state)

      {:ok, :execute, channel_id, topic, action, args, params} ->
        handle_execute(channel_id, topic, action, args, params, state)

      {:ok, :subscribe, channel_id, topic, params} ->
        handle_subscribe(channel_id, topic, params, state)

      {:ok, :unsubscribe, channel_id} ->
        handle_unsubscribe(channel_id, state)
    end
  end

  def handle_info(info, state) do
    case info do
      {:reset, ref, value} ->
        case Map.fetch(state.channel_ids, ref) do
          {:ok, channel_id} ->
            {:ok, [Response.encode_topic_reset(channel_id, value)], state}

          :error ->
            {:ok, [], state}
        end

      {:updates, ref, updates} ->
        case Map.fetch(state.channel_ids, ref) do
          {:ok, channel_id} ->
            {:ok, [Response.encode_topic_updates(channel_id, updates)], state}

          :error ->
            {:ok, [], state}
        end

      _other ->
        {:ok, [], state}
    end
  end

  defp handle_notify(topic, action, args, params, state) do
    # TODO: handle some errors (e.g., with lookup/init topic?)
    case Topical.notify(state.registry, topic, action, List.to_tuple(args), state.context, params) do
      :ok ->
        {:ok, [], state}
    end
  end

  defp handle_execute(channel_id, topic, action, args, params, state) do
    # TODO: don't block?
    case Topical.execute(
           state.registry,
           topic,
           action,
           List.to_tuple(args),
           state.context,
           params
         ) do
      {:ok, result} ->
        {:ok, [Response.encode_result(channel_id, result)], state}

      {:error, error} ->
        {:ok, [Response.encode_error(channel_id, error)], state}
    end
  end

  defp handle_subscribe(channel_id, topic, params, state) do
    # Get the normalized topic key to check for existing subscriptions
    case Registry.topic_key(state.registry, topic, params) do
      {:ok, topic_key} ->
        case Map.fetch(state.topic_keys, topic_key) do
          {:ok, existing_channel_id} ->
            # Already subscribed to this topic - send alias response
            {:ok, [Response.encode_topic_alias(channel_id, existing_channel_id)], state}

          :error ->
            # New subscription
            do_subscribe(channel_id, topic, params, topic_key, state)
        end

      {:error, error} ->
        {:ok, [Response.encode_error(channel_id, error)], state}
    end
  end

  defp do_subscribe(channel_id, topic, params, topic_key, state) do
    case Topical.subscribe(state.registry, topic, self(), state.context, params) do
      {:ok, ref} ->
        # Store params along with topic and ref for use during unsubscribe
        state =
          state
          |> put_in([:channels, channel_id], {topic, ref, params, topic_key})
          |> put_in([:channel_ids, ref], channel_id)
          |> put_in([:topic_keys, topic_key], channel_id)

        {:ok, [], state}

      {:error, error} ->
        {:ok, [Response.encode_error(channel_id, error)], state}
    end
  end

  defp handle_unsubscribe(channel_id, state) do
    case Map.fetch(state.channels, channel_id) do
      {:ok, {topic, ref, params, topic_key}} ->
        :ok = Topical.unsubscribe(state.registry, topic, ref, params)

        state =
          state
          |> Map.update!(:channels, &Map.delete(&1, channel_id))
          |> Map.update!(:channel_ids, &Map.delete(&1, ref))
          |> Map.update!(:topic_keys, &Map.delete(&1, topic_key))

        {:ok, [], state}

      :error ->
        # Channel not found (maybe it was an alias that was never stored)
        {:ok, [], state}
    end
  end
end
