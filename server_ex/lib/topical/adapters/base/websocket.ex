defmodule Topical.Adapters.Base.WebSocket do
  @moduledoc false

  alias Topical.Protocol.{Request, Response}

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
          channel_ids: %{}
        }

        {:ok, state}
    end
  end

  def handle_text(text, state) do
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

  defp handle_notify(topic, action, args, state) do
    # TODO: handle some errors (e.g., with lookup/init topic?)
    case Topical.notify(state.registry, topic, action, List.to_tuple(args), state.context) do
      :ok ->
        {:ok, [], state}
    end
  end

  defp handle_execute(channel_id, topic, action, args, state) do
    # TODO: don't block?
    case Topical.execute(state.registry, topic, action, List.to_tuple(args), state.context) do
      {:ok, result} ->
        {:ok, [Response.encode_result(channel_id, result)], state}

      {:error, error} ->
        {:ok, [Response.encode_error(channel_id, error)], state}
    end
  end

  defp handle_subscribe(channel_id, topic, state) do
    case Topical.subscribe(state.registry, topic, self(), state.context) do
      {:ok, ref} ->
        state =
          state
          |> put_in([:channels, channel_id], {topic, ref})
          |> put_in([:channel_ids, ref], channel_id)

        {:ok, [], state}

      {:error, error} ->
        {:ok, [Response.encode_error(channel_id, error)], state}
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

        {:ok, [], state}
    end
  end
end
