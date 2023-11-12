defmodule Cache.WidgetTopic do
  use Topical.Topic, route: ["widgets", :widget_id]

  def init(_params) do
    widget = load_widget()
    schedule_tick()
    {:ok, Topic.new(widget)}
  end

  def handle_info(:tick, topic) do
    quantity = max(0, topic.value.quantity + Enum.random(-10..10))
    topic = Topic.set(topic, [:quantity], quantity)
    schedule_tick()
    {:ok, topic}
  end

  defp load_widget() do
    Process.sleep(2_000)
    size = Enum.random(5..120)
    colour = Enum.random(["blue", "green", "red", "yellow"])
    quantity = Enum.random(10..200)
    %{size: size, colour: colour, quantity: quantity}
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, Enum.random(500..2_500))
  end
end
