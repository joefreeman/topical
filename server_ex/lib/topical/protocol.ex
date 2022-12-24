defmodule Topical.Protocol do
  defmodule Request do
    def decode(text) do
      case Jason.decode(text) do
        {:ok, [0, topic, action, args]} ->
          {:ok, :notify, topic, action, args}

        {:ok, [1, channel_id, topic, action, args]} ->
          {:ok, :execute, channel_id, topic, action, args}

        {:ok, [2, channel_id, topic]} ->
          {:ok, :subscribe, channel_id, topic}

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

    defp encode_update(update) do
      case update do
        {:set, path, value} -> [0, path, value]
        {:unset, path, key} -> [1, path, key]
        {:insert, path, index, values} -> [2, path, index, values]
        {:delete, path, index, count} -> [3, path, index, count]
      end
    end
  end
end
