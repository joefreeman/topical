defmodule Todo.ListsTopic do
  use Topical.Topic, route: "lists"

  @interval_ms 1_000

  def init(_params) do
    lists = get_lists()
    schedule_tick()
    {:ok, Topic.new(Map.new(lists, &{&1, true}))}
  end

  def handle_info(:tick, topic) do
    lists = get_lists()

    topic =
      lists
      |> Enum.reject(&Map.has_key?(topic.value, &1))
      |> Enum.reduce(topic, fn added, topic ->
        Topic.set(topic, [added], true)
      end)

    topic =
      topic.value
      |> Map.keys()
      |> Enum.reject(&(&1 in lists))
      |> Enum.reduce(topic, fn removed, topic ->
        Topic.unset(topic, [], removed)
      end)

    schedule_tick()
    {:ok, topic}
  end

  defp get_lists() do
    "lists" |> File.ls!()
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, @interval_ms)
  end
end
