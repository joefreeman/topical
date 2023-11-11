defmodule Todo.ListsTopic do
  use Topical.Topic, route: "lists"

  @path "data/index"

  def init(_params) do
    lists =
      if File.exists?(@path) do
        with {:ok, content} <- File.read(@path) do
          :erlang.binary_to_term(content)
        end
      else
        []
      end

    {:ok, Topic.new(lists)}
  end

  def handle_execute("add_list", {name}, topic, _context) do
    id = Integer.to_string(:erlang.system_time())
    topic = Topic.insert(topic, [], length(topic.value), %{id: id, name: name})
    content = :erlang.term_to_binary(topic.value)
    @path |> Path.dirname() |> File.mkdir_p!()
    File.write!(@path, content)
    {:ok, id, topic}
  end
end
