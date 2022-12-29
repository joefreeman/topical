defmodule Canvas.Topics.CanvasTopic do
  use Topical.Topic, route: "canvas"

  def init(_params) do
    {:ok, Topic.new(%{cursors: %{}})}
  end

  def handle_subscribe(topic, context) do
    client_id = Map.fetch!(context, :client_id)
    {:ok, Topic.set(topic, [:cursors, client_id], %{})}
  end

  def handle_unsubscribe(topic, context) do
    client_id = Map.fetch!(context, :client_id)
    {:ok, Topic.unset(topic, [:cursors], client_id)}
  end

  def handle_notify("cursor_move", {}, topic, context) do
    client_id = Map.fetch!(context, :client_id)
    {:ok, Topic.unset(topic, [:cursors, client_id], :position)}
  end

  def handle_notify("cursor_move", {x, y}, topic, context) do
    client_id = Map.fetch!(context, :client_id)
    {:ok, Topic.set(topic, [:cursors, client_id, :position], %{x: x, y: y})}
  end
end
