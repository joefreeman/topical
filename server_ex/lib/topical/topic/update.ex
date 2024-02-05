defmodule Topical.Topic.Update do
  @moduledoc false

  import Kernel, except: [apply: 2, update_in: 3]

  def apply(value, update) do
    case update do
      {:set, path, new_value} ->
        update_in(value, path, fn _ -> new_value end)

      {:unset, path, key} ->
        update_in(value, path, &Map.delete(&1, key))

      {:insert, path, index, new_values} ->
        update_in(value, path, &insert_at(&1, index, new_values))

      {:delete, path, index, count} ->
        update_in(value, path, &delete_at(&1, index, count))

      {:merge, path, new} ->
        update_in(value, path, &Map.merge(&1 || %{}, new))
    end
  end

  defp update_in(value, path, fun) do
    case path do
      [] ->
        fun.(value)

      [index | rest] when is_integer(index) ->
        if !is_list(value), do: raise("not list")
        if index >= length(value), do: raise("index out of range")
        List.update_at(value, index, &update_in(&1, rest, fun))

      [key | rest] ->
        (value || %{})
        |> Map.put_new(key, nil)
        |> Map.update!(key, &update_in(&1, rest, fun))
    end
  end

  defp insert_at([], _index, values) do
    values
  end

  defp insert_at(list, nil, values) do
    list ++ values
  end

  defp insert_at(list, 0, values) do
    values ++ list
  end

  defp insert_at([head | tail], index, value) do
    [head | insert_at(tail, index - 1, value)]
  end

  defp delete_at(list, index, count) do
    Enum.take(list, index) ++ Enum.drop(list, index + count)
  end
end
