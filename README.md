# Topical

_Simple server-maintained state synchronisation._

Implement an Elixir module, which defines how to: initialise the topic when needed, react to
requests from connected clients, and/or handle server-side events. On the client side you can use a
React hook (or the JavaScript library directly) to get a copy of the state that updates in
real-time.

For example a partial implementation of a todo list topic:

```elixir
defmodule MyApp.Topics.List do
  use Topical.Topic, route: "lists/:list_id"

  def init(params) do
    # Get the ID from the route (unused here)
    list_id = Keyword.fetch!(params, :list_id)

    # Initialise an empty list (alternatively load it from a file/database/service)
    value = %{items: %{}, order: []}
    {:ok, Topic.new(value)}
  end

  def handle_execute("add_item", {text}, topic) do
    id = Integer.to_string(:erlang.system_time())

    # Update the topic by putting the item in 'items', and appending the ID to 'order'
    topic =
      topic
      |> Topic.set([:items, id], %{text: text, done: false})
      |> Topic.insert([:order], id)

    # Return the result (the ID), and the updated topic
    {:ok, id, topic}
  end
end
```

And a corresponding React component:

```typescript
import { SocketProvider, useTopic } from "topical";

function TodoList({ id}) {
  const [list, { execute }] = useTopic(`lists/${id}`);
  const handleAddClick = useCallback(() => execute("add_item", prompt()), [execute]);
  if (list) {
    return (
      <div>
        <ol>
          {list.order.map((itemId) => {
            const { text, done } = list.items[itemId];
            return (
              <li
                key={itemId}
                className={done ? "done" : undefined}
              >
                {text}
              </li>
            );
          })}
        </ol>
        <button onClick={handleAddClick}>Add item</button>
      </div>
    );
  } else {
    return <p>Loading...</p>
  }
}

function App() {
  return (
    <SocketProvider url="...">
      <TodoList id="foo" />
      <TodoList id="bar" />
    </SocketProvider>
  );
}
```

Updates are sent efficiently over a WebSocket connection. The server takes care of starting topics
when needed, and stopping them when no clients are connected. Multiple clients (and users) can
share a single instance of a topic.

## Repository

This repository is separated into:

  - `server_ex` - the Elixir library for implementing topic servers, including a WebSocket adapter for the Cowboy web server.
  - `client_js` - the vanilla JavaScript WebSocket client.
  - `client_react` - React hooks built on top of the JavaScript client.
  - `examples/todo` - a complete todo list example.

More complete documentation is associated with the Elixir project, and is available on [HexDocs](https://hexdocs.pm/topical/).

## License

Topical is released under the Apache License 2.0.
