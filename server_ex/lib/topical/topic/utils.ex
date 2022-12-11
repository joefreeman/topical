defmodule Topical.Topic.Utils do
  def apply_update({path, value}, state) do
    case path do
      [] ->
        value

      [key] ->
        if is_nil(value) do
          Map.delete(state, key)
        else
          Map.put(state, key, value)
        end

      [key | rest] ->
        map =
          case Map.fetch(state, key) do
            {:ok, map} when is_map(map) -> map
            _other -> %{}
          end

        Map.put(state, key, apply_update({rest, value}, map))
    end
  end
end
