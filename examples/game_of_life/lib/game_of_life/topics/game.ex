defmodule GameOfLife.GameTopic do
  use Topical.Topic, route: "games/:game_id"

  @interval_ms 100
  @neighbours for x <- -1..1, y <- -1..1, x != 0 or y != 0, do: {x, y}

  def init(_params) do
    {:ok, Topic.new(%{width: 50, height: 50, alive: [], running: false})}
  end

  def handle_notify("spawn", {x, y}, topic, _context) do
    topic = if alive?(topic, {x, y}), do: topic, else: spawn(topic, [{x, y}])
    {:ok, topic}
  end

  def handle_notify("kill", {x, y}, topic, _context) do
    topic = if alive?(topic, {x, y}), do: kill(topic, [{x, y}]), else: topic
    {:ok, topic}
  end

  def handle_notify("step", {}, topic, _context) do
    {:ok, step(topic)}
  end

  def handle_notify("start", {}, topic, _context) do
    unless topic.value.running do
      Process.send_after(self(), :tick, @interval_ms)
    end

    {:ok, Topic.set(topic, [:running], true)}
  end

  def handle_notify("stop", {}, topic, _context) do
    {:ok, Topic.set(topic, [:running], false)}
  end

  def handle_info(:tick, topic) do
    if topic.value.running do
      Process.send_after(self(), :tick, @interval_ms)
    end

    {:ok, step(topic)}
  end

  defp step(topic) do
    alive = get_alive(topic)
    dead = get_dead(alive, topic)
    births = Enum.filter(dead, &(count_neighbours(&1, alive, topic) == 3))
    deaths = Enum.filter(alive, &(count_neighbours(&1, alive, topic) not in 2..3))
    topic |> kill(deaths) |> spawn(births)
  end

  defp get_alive(topic) do
    topic.value.alive
    |> Enum.map(fn [x, y] -> {x, y} end)
    |> MapSet.new()
  end

  defp alive?(topic, {x, y}) do
    MapSet.member?(get_alive(topic), {x, y})
  end

  defp get_neighbours({x, y}, topic) do
    %{width: width, height: height} = topic.value

    @neighbours
    |> Enum.map(fn {dx, dy} -> {x + dx, y + dy} end)
    |> Enum.filter(fn {x, y} -> 0 <= x and x < width and 0 <= y and y < height end)
    |> MapSet.new()
  end

  defp get_dead(alive, topic) do
    alive
    |> Enum.map(&get_neighbours(&1, topic))
    |> Enum.reduce(MapSet.new(), &MapSet.union/2)
    |> MapSet.difference(alive)
  end

  defp count_neighbours(cell, alive, topic) do
    cell
    |> get_neighbours(topic)
    |> Enum.count(&MapSet.member?(alive, &1))
  end

  defp spawn(topic, cells) do
    Topic.insert(topic, [:alive], Enum.map(cells, fn {x, y} -> [x, y] end))
  end

  defp kill(topic, cells) do
    Enum.reduce(cells, topic, fn cell, topic ->
      index = Enum.find_index(topic.value.alive, fn [x, y] -> {x, y} == cell end)
      Topic.delete(topic, [:alive], index)
    end)
  end
end
