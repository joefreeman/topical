defmodule Todo.ListTopic do
  use Topical.Topic, route: "lists/:list_id"

  def init(params) do
    list_id = Keyword.fetch!(params, :list_id)
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

  def handle_execute("add_item", {text}, topic) do
    id = generate_id(topic.value.items)

    topic =
      topic
      |> Topic.set([:items, id], %{text: text})
      |> Topic.insert([:order], id)

    {:ok, id, topic}
  end

  def handle_notify("update_text", {id, text}, topic) do
    {:ok, Topic.set(topic, [:items, id, :text], text)}
  end

  def handle_notify("update_done", {id, done}, topic) do
    {:ok, Topic.set(topic, [:items, id, :done], done)}
  end

  def terminate(_reason, topic) do
    path = get_path(topic.state.list_id)
    content = :erlang.term_to_binary(topic.value)
    File.write!(path, content)
  end

  defp get_path(list_id) do
    "data/lists/#{list_id}"
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
