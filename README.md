# Topical

Simple server-maintained state synchronisation.

Implement an Elixir module, which defines how to: initialise the topic when needed, react to requests from connected clients, and/or handle server-side events. On the client side you can use a React hook (or the JavaScript library directly) to get a copy of the state that updates in real-time.

For example a partial implementation of a todo list topic:

```elixir
defmodule MyApp.Topics.List do
  use Topical.Topic, route: "lists/:list_id"

  def init(params) do
    list_id = Keyword.fetch!(params, :list_id)
    value = %{items: %{}, order: []} # exposed ‘value’ of the topic
    state = %{list_id: list_id} # hidden server state
    {:ok, Topic.new(value, state)}
  end

  def handle_execute("add_item", {text}, topic) do
    id = Integer.to_string(:erlang.system_time())

    # update the topic by putting the item in ‘items’, and appending the id to ‘order’
    topic =
      topic
      |> Topic.set([:items, id], %{text: text, done: false})
      |> Topic.insert([:order], id)

    # return result (the id), and the updated topic
    {:ok, id, topic}
  end
end
```

And a React component:

```typescript
import { SocketProvider, useTopic } from "topical";

function TodoList({ name }) {
  const [list, { execute }] = useTopic(`lists/${name}`);
  const addItem = useCallback((text) => execute("add_item", text), [execute]);
  // …
}

function App() {
  return (
    <SocketProvider url="...">
      <TodoList name="foo" />
      <TodoList name="bar" />
    </SocketProvider>
  );
}
```

Updates are sent efficiently over a WebSocket connection. The server takes care of starting topics, and stopping them when no clients are connected. Multiple clients (and users) can share a single instance of a topic.

# License

Topical is released under the Apache License 2.0.
