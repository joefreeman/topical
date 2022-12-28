# JavaScript client

You can connect to a Topical server that has been exposed by an adapter, using the JavaScript
client. The client is available on npm:

```sh
npm install @topical/core
```

(Or you may prefer to use the React client - see below.)

```typescript
type ListModel = {
  items: Record<string, { text: string, done: boolean }>;
  order: string[];
}

// Setup the socket
const socket = new Socket("ws://example.com/socket");

// Subscribe to a topic (returns a function to unsibscribe)
const unsubscribe = socket.subscribe<ListModel>(
  "lists/foo",
  (list: ListModel) => { console.log(value); },
  (error) => { ... }
);

// Execute an action
const itemId = await socket.execute("lists/foo", "add_item", "First item");

// (The subscription should have been updated)

// Send a notification
socket.notify("lists/foo", "update_item", itemId, "Inaugural item")

// (The subscription should have been updated again)

// Unsubscribe
unsubscribe();
```

## React client

Instead of using the JavaScript client directly, you can use the React client. Install it from npm:

```sh
npm install @topical/react
```

Setup the socket using the provider:

```typescript
import { SocketProvider } from "@topical/react";

function getSocketUrl() {
  // TODO
  return "ws://example.com/socket";
}

function App() {
  return (
    <SocketProvider url={getSocketUrl()}>
      // ...
    </SocketProvider>
  );
}
```

Then use the `useTopic` hook in your components to subscribe to your topic:

```typescript
import { useTopic } from "@topical/react";

function List({ id }) {
  const [list, { execute, notify }] = useTopic<models.List>(`lists/${id}`);
  const addItem = useCallback(
    (text: string) => execute("add_item", text),
    [execute]
  );
  if (list) {
    return (
      // ...
    );
  } else {
    return <p>Loading...</p>
  }
}
```

If you need access to the underlying socket (or the status), you can use the `useSocket` hook:

```typescript
import { useSocket } from "@topical/react";

function SocketStatus() {
  const [_socket, state] = useSocket();
  return <p>{state}</p>;
}
```
