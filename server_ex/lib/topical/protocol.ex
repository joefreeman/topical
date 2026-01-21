defmodule Topical.Protocol do
  @moduledoc false

  defmodule Request do
    @moduledoc false

    def decode(text) do
      case Jason.decode(text) do
        # Notify: [0, topic, action, args] or [0, topic, action, args, params]
        {:ok, [0, topic, action, args]} ->
          {:ok, :notify, topic, action, args, %{}}

        {:ok, [0, topic, action, args, params]} when is_map(params) ->
          {:ok, :notify, topic, action, args, params}

        # Execute: [1, channel_id, topic, action, args] or [1, channel_id, topic, action, args, params]
        {:ok, [1, channel_id, topic, action, args]} ->
          {:ok, :execute, channel_id, topic, action, args, %{}}

        {:ok, [1, channel_id, topic, action, args, params]} when is_map(params) ->
          {:ok, :execute, channel_id, topic, action, args, params}

        # Subscribe: [2, channel_id, topic] or [2, channel_id, topic, params]
        {:ok, [2, channel_id, topic]} ->
          {:ok, :subscribe, channel_id, topic, %{}}

        {:ok, [2, channel_id, topic, params]} when is_map(params) ->
          {:ok, :subscribe, channel_id, topic, params}

        # Unsubscribe: [3, channel_id]
        {:ok, [3, channel_id]} ->
          {:ok, :unsubscribe, channel_id}

        {:ok, _other} ->
          {:error, :unrecognised_command}

        _other ->
          {:error, :decode_failure}
      end
    end
  end

  defmodule Response do
    @moduledoc false

    def encode_error(channel_id, error) do
      Jason.encode!([0, channel_id, error])
    end

    def encode_result(channel_id, result) do
      Jason.encode!([1, channel_id, result])
    end

    def encode_topic_reset(channel_id, value) do
      Jason.encode!([2, channel_id, value])
    end

    def encode_topic_updates(channel_id, updates) do
      Jason.encode!([3, channel_id, Enum.map(updates, &encode_update/1)])
    end

    def encode_topic_alias(channel_id, existing_channel_id) do
      Jason.encode!([4, channel_id, existing_channel_id])
    end

    defp encode_update(update) do
      case update do
        {:set, path, value} -> [0, path, value]
        {:unset, path, key} -> [1, path, key]
        {:insert, path, index, values} -> [2, path, index, values]
        {:delete, path, index, count} -> [3, path, index, count]
        {:merge, path, value} -> [4, path, value]
      end
    end
  end
end
