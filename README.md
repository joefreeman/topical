<br />

<p align="center">
  <img src="logo.png" width="350" alt="Topical" />
</p>

<br />

<p align="center">
  <a href="https://hex.pm/packages/topical"><img src="https://img.shields.io/hexpm/v/topical.svg?color=6e4a7e" /></a>
  <a href="https://www.npmjs.com/package/@topical/core"><img src="https://img.shields.io/npm/v/@topical/core.svg?color=3178c6" /></a>
  <a href="https://www.npmjs.com/package/@topical/react"><img src="https://img.shields.io/npm/v/@topical/react.svg?color=087ea4" /></a>
</p>

<br />

Topical is an Elixir library for synchronising server-maintained state (_topics_) to connected clients. Topic lifecycle is managed by the server: topics are initialised as needed, shared between subscribing clients, and automatically shut down when not in use.

The accompanying JavaScript library (and React hooks) allow clients to easily connect to topics, and efficiently receive real-time updates. Clients can also send requests (or notifications) upstream to the server.

<p align="center">
  <img src="architecture.png" width="400" alt="Architecture diagram" />
</p>

See the [Getting started](https://hexdocs.pm/topical/getting-started.html) guide.

## Ephemeral or persistent state

In its simplest instance, a topic's state can be ephemeral - i.e., discarded when the topic is shut down. For example, for synchronising cursor positions of users (see [canvas](examples/canvas/) example).

Alternatively state could be persisted - e.g., to a database - with the topic subscribing to updates from the database, which allows separating mutation logic, and replication of topics. In the case where lower durability can be afforded, state can be periodically flushed to disk.

## Comparison to LiveView

Topical solves a similar problem to Phoenix LiveView, but at a different abstraction level, by dealing only with the underlying state, rather than rendering HTML and handling UI events.

## Adapters

There are WebSocket adapters for [Cowboy](https://github.com/ninenines/cowboy) and [WebSock](https://github.com/phoenixframework/websock) (compatible with [Plug](https://github.com/elixir-plug/plug) and [Bandit](https://github.com/mtrudel/bandit)), which allow adding Topical into an existing application. Either of these are required to support the JavaScript client and the full functionality of Topical. See [`examples/todo`](examples/todo/) for an example of both (running simultaneously).

Additionally, a REST-like adapter provides a way for clients to capture a snapshot of a topic (which is useful for supporing the incremental cache use case).

## Example: todo list

A partial implementation of a todo list topic might look like this:

```elixir
defmodule MyApp.Topics.List do
  use Topical.Topic, route: ["lists", :list_id]

  # Initialise the topic
  def init(params) do
    # Get the ID from the route (unused here)
    list_id = Keyword.fetch!(params, :list_id)

    # TODO: subscribe to events from, e.g., database/pub-sub
    # TODO: load list from, e.g., database/API

    value = %{items: %{}, order: []}
    {:ok, Topic.new(value)}
  end

  # Handle a message - e.g., from subscription
  def handle_info({:done, id}, topic) do
    topic = Topic.set(topic, [:items, id, :done], true)
    {:ok, topic}
  end

  # Handle a request from a connected client
  def handle_execute("add_item", {text}, topic, _context) do
    id =
      topic.state.items
      |> Enum.count()
      |> Integer.to_string()

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
import { SocketProvider, useTopic } from "@topical/react";

function TodoList({ id }) {
  const [list, { execute, loading, error }] = useTopic("lists", id);
  const handleAddClick = useCallback(
    () => execute("add_item", prompt()),
    [execute]
  );
  if (loading) {
    return <p>Loading...</p>;
  } else if (error) {
    return <p>Error.</p>
  } else {
    return (
      // ...
    );
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

See [`examples/todo`](examples/todo/) for a more complete example.

## Other examples

- [`examples/todo`](examples/todo/) - A more complete todo example, with basic persistence.
- [`examples/canvas`](examples/canvas/) - A simple canvas drawing example, with synchronised cursors.
- [`examples/game_of_life`](examples/game_of_life/) - Conway's Game of Life.
- [`examples/cache`](examples/cache/) - Using Topical as an incremental cache.

## Documentation

Documentation is available on [HexDocs](https://hexdocs.pm/topical/).

## Development

This repository is separated into:

- [`server_ex`](server_ex/) - the Elixir library for implementing topic servers, including adapters.
- [`client_js`](client_js/) - the vanilla JavaScript WebSocket client.
- [`client_react`](client_react/) - React hooks built on top of the JavaScript client.

## License

Topical is released under the Apache License 2.0.
