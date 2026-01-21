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

// Subscribe to a topic (returns a function to unsubscribe)
const unsubscribe = socket.subscribe<ListModel>(
  ["lists", "foo"],
  (list: ListModel) => { console.log(list); },
  (error) => { ... }
);

// Execute an action (args is an array)
const itemId = await socket.execute(["lists", "foo"], "add_item", ["First item"]);

// (The subscription should have been updated)

// Send a notification (args is an array)
socket.notify(["lists", "foo"], "update_item", [itemId, "Inaugural item"]);

// (The subscription should have been updated again)

// Unsubscribe
unsubscribe();
```

## Parameters

Topics can declare optional parameters. For `subscribe`, pass params after the topic and
before the callbacks. For `execute` and `notify`, pass params as the last argument:

```typescript
// Subscribe to a regional leaderboard (params before callbacks)
const unsubscribe = socket.subscribe<Leaderboard>(
  ["leaderboards", "chess"],
  { region: "eu" },  // params
  (leaderboard) => { console.log(leaderboard); },
  (error) => { ... }
);

// Execute with params (params at end)
await socket.execute(
  ["leaderboards", "chess"],
  "add_score",
  ["alice", 100],   // args array
  { region: "eu" }  // params
);

// Notify with params (params at end)
socket.notify(
  ["leaderboards", "chess"],
  "add_score",
  ["bob", 200],     // args array
  { region: "eu" }  // params
);
```

Different param values create separate topic instances. The server handles deduplication
automatically - if you subscribe to the same topic with equivalent params multiple times,
the client will receive an alias response and merge the subscriptions.

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
  const [list, { execute, notify, loading, error }] = useTopic<models.List>(
    ["lists", id]
  );
  const addItem = useCallback(
    (text: string) => execute("add_item", [text]),
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
```

### Parameters with useTopic

Pass params as the second argument:

```typescript
function Leaderboard({ gameId, region }) {
  const [leaderboard, { execute, loading, error }] = useTopic<models.Leaderboard>(
    ["leaderboards", gameId],
    { region }  // params
  );

  const addScore = useCallback(
    (player: string, score: number) => execute("add_score", [player, score]),
    [execute]
  );

  // ...
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
