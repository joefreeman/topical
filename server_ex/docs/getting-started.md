# Getting started

First you need to implement a topic definition. For example, a todo list topic might track todo
items and their order, handle requests from clients to add new items or update the text of existing
items, and handle Erlang messages from a separate process indicating when items are done:

```elixir
defmodule MyApp.Topics.List do
  use Topical.Topic, route: "lists/:list_id"

  # Initialise the topic
  def init(params) do
    list_id = Keyword.fetch!(params, :list_id)

    value = %{items: %{}, order: []} # exposed 'value' of the topic
    state = %{list_id: list_id, last_item_id: 0} # hidden server state
    topic = Topic.new(value, state)

    {:ok, topic}
  end

  # Optionally, handle execution of an action
  def handle_execute("add_item", {text}, topic, _context) do
    {id, topic} = generate_item_id(topic)

    # Update the topic by putting the item in 'items', and appending the id to 'order'
    topic =
      topic
      |> Topic.set([:items, id], %{text: text, done: false})
      |> Topic.insert([:order], id)

    # Return the result (the 'id'), and the updated topic
    {:ok, id, topic}
  end

  defp generate_item_id(topic) do
    id = topic.state.last_item_id + 1
    topic = put_in(topic[:state][:last_item_id], id)
    {Integer.to_string(id), topic}
  end

  # Optionally, handle a notification (an action without a result)
  def handle_notify("update_text", {id, text}, topic) do
    topic  = Topic.set(topic, [:items, id, :text], text)
    {:ok, topic}
  end

  # Optionally, handle Erlang messages
  def handle_info({:done, id}, topic) do
    topic  = Topic.set(topic, [:items, id, :done], true)
    {:ok, topic}
  end
end
```

Then add a Topical registry to your application supervision tree, referencing the topic:

```elixir
defmodule MyApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # ...
      {Topical, name: MyApp.Topical, topics: [MyApp.Topics.List, ...]},
    ]

    Supervisor.start_link(children, ...)
  end
end
```

At this point you should be able to subscribe to the topic:

```elixir
{:ok, ref} = Topical.subscribe(MyApp.Topical, "lists/foo", self())
```

After subscribing, the process will be sent an initial `{:reset, ref, value}` message (where `ref`
is the subscription reference returned from `subscribe`), and then subsequent
`{:updates, ref, updates}` messages, where `updates` is a list of updates, each taking the form:

- `{:set, path, value}`: the `value` has been set at the `path`.
- `{:unset, path, key}`: the `key` has been unset from the object at the `path`.
- `{:insert, path, index, values}`: the `values` have been inserted into the array at the `path`.
- `{:delete, path, index, count}`: `count` values have been deleted from the array at the `path`, from the position `index`.

(You can receive any waiting messages on an IEx shell with:
`receive do x -> x after 0 -> nil end`.)

To execute an action:

```elixir
{:ok, item_id} = Topical.execute(MyApp.Topical, "lists/foo", "add_item", {"Test item", false})
```

To unsubscribe:

```elixir
Topical.unsubscribe(MyApp.Topical, "lists/foo", ref)
```

However, rather than using the API from Elixir, you may wish to set up the
[Cowboy adapter](cowboy-adapter.md), and then use the [JavaScript client](javascript-client.md).
