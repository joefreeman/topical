![Topical](logo.png)

Topical is an Elixir library for synchronising server-maintained state ('topics') to connected clients. Topic lifecycle is managed by the server: topics are initialised as needed, shared between subscribing clients, and automatically shut down when not in use.

The accompanying JavaScript library (and React hooks) allow clients to easily connect to topics, and efficiently receive real-time updates. Clients can also send requests (or notifications) upstream to the server.

## Ephemeral or persistent state

In its simplest instance, a topic's state can be ephemeral - i.e., discarded when the topic is shut down. For example, for synchronising cursor positions.

Alternatively state could be persisted - e.g., to a database - with the topic subscribing to updates from the database. Or (where lower durability is needed), periodically flushed to disk.

## Comparison to LiveView

Topical solves a similar problem to Phoenix LiveView, but at a different abstraction level, by dealing with the underlying state, rather than rendering HTML and handling UI events.

## Example (todo list)

For example a partial implementation of a todo list topic:

```elixir
defmodule MyApp.Topics.List do
  use Topical.Topic, route: "lists/:list_id"

  # Initialise the topic
  def init(params) do
    # Get the ID from the route (unused here)
    list_id = Keyword.fetch!(params, :list_id)

    # Initialise an empty list (alternatively load it from a file/database/service)
    value = %{items: %{}, order: []}
    {:ok, Topic.new(value)}
  end

  # Handle an 'add_item' request from a client
  def handle_execute("add_item", {text}, topic, _context) do
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
  const [list, { execute }] = useTopic("lists", id);
  const handleAddClick = useCallback(() => execute("add_item", prompt()), [execute]);
  if (list) {
    return (
      <div>
        <ol>
          {list.order.map((itemId) => {
            const { text, done } = list.items[itemId];
            return <li key={itemId} className={done ? "done" : undefined}>{text}</li>;
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

See `examples/todo` for a more complete example.

## Documentation

Documentation is available on [HexDocs](https://hexdocs.pm/topical/).

## Development

This repository is separated into:

  - `server_ex` - the Elixir library for implementing topic servers, including a WebSocket adapter for the Cowboy web server.
  - `client_js` - the vanilla JavaScript WebSocket client.
  - `client_react` - React hooks built on top of the JavaScript client.

## License

Topical is released under the Apache License 2.0.
