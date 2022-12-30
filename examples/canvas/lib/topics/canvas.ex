defmodule Canvas.Topics.CanvasTopic do
  use Topical.Topic, route: "canvases/:canvas_id"

  @colors [
    "#147EB3",
    "#29A634",
    "#D1980B",
    "#D33D17",
    "#9D3F9D",
    "#00A396",
    "#DB2C6F",
    "#8EB125",
    "#946638",
    "#7961DB"
  ]

  def init(_params) do
    {:ok, Topic.new(%{cursors: %{}, paths: []})}
  end

  def handle_subscribe(topic, context) do
    client_id = Map.fetch!(context, :client_id)
    color = Enum.at(@colors, :erlang.phash2(client_id, length(@colors)))
    {:ok, Topic.set(topic, [:cursors, client_id], %{color: color})}
  end

  def handle_unsubscribe(topic, context) do
    client_id = Map.fetch!(context, :client_id)
    {:ok, Topic.unset(topic, [:cursors], client_id)}
  end

  def handle_notify("set_position", {}, topic, context) do
    client_id = Map.fetch!(context, :client_id)
    {:ok, Topic.unset(topic, [:cursors, client_id], :position)}
  end

  def handle_notify("set_position", {x, y}, topic, context) do
    client_id = Map.fetch!(context, :client_id)
    topic = Topic.set(topic, [:cursors, client_id, :position], %{x: x, y: y})

    topic =
      if Map.has_key?(topic.value.cursors[client_id], :drawing) do
        Topic.insert(topic, [:cursors, client_id, :drawing], [[x, y]])
      else
        topic
      end

    {:ok, topic}
  end

  def handle_notify("set_drawing", {drawing}, topic, context) do
    client_id = Map.fetch!(context, :client_id)

    topic =
      if drawing do
        Topic.set(topic, [:cursors, client_id, :drawing], [])
      else
        finish_drawing(topic, client_id)
      end

    {:ok, topic}
  end

  defp finish_drawing(topic, client_id) do
    cursor = Map.fetch!(topic.value.cursors, client_id)
    path = Map.get(cursor, :drawing)
    topic = Topic.unset(topic, [:cursors, client_id], :drawing)

    if path && length(path) > 0 do
      color = Map.fetch!(cursor, :color)
      Topic.insert(topic, [:paths], %{path: path, color: color})
    else
      topic
    end
  end
end
