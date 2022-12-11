defmodule Todo.ListTopic do
  use Topical.Topic, name: "list"

  def init(list_id) do
    path = get_path(list_id)

    value =
      if File.exists?(path) do
        with {:ok, content} <- File.read(path) do
          :erlang.binary_to_term(content)
        end
      else
        %{items: %{}, order: []}
      end

    {:ok, Topic.new(value, %{list_id: list_id})}
  end

  def handle_execute({:add_item, text}, topic) do
    id = generate_id(topic.value.items)

    topic =
      topic
      |> Topic.update([:items, id], %{text: text})
      |> Topic.update([:order], topic.value.order ++ [id])

    {:ok, id, topic}
  end

  def handle_execute({:update_item, id, text}, topic) do
    {:ok, nil, Topic.update(topic, [:items, id, text], text)}
  end

  def terminate(_reason, topic) do
    path = get_path(topic.state.list_id)
    content = :erlang.term_to_binary(topic.value)
    File.write!(path, content)
  end

  defp get_path(list_id) do
    "lists/#{list_id}"
  end

  defp generate_id(existing_items, attempts \\ 0) do
    id = random_string(attempts + 3)

    if Map.has_key?(existing_items, id) do
      generate_id(existing_items, attempts + 1)
    else
      id
    end
  end

  defp random_string(length) do
    chars = String.codepoints("abcdefghjkmnpqrstuvwxyz23456789")

    1..length
    |> Enum.map(fn _i -> Enum.random(chars) end)
    |> Enum.join("")
  end
end
