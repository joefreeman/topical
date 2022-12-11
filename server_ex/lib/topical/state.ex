defmodule Topical.State do
  def update(state, path, value) do
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

        Map.put(state, key, update(map, rest, value))
    end
  end
end
