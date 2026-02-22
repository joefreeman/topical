# Topical Go Client

A Go client for [Topical](https://github.com/joefreeman/topical), a real-time state synchronization library. Connects to a Topical server over WebSocket and keeps local state in sync.

## Install

```
go get github.com/joefreeman/topical/client_go
```

## Usage

### Connecting

```go
ctx := context.Background()
client, err := topical.Connect(ctx, "ws://localhost:4000/socket")
if err != nil {
    log.Fatal(err)
}
defer client.Close()
```

By default the client reconnects automatically with exponential backoff. This can be configured:

```go
client, err := topical.Connect(ctx, url,
    topical.WithReconnect(false),
    topical.WithBackoff(1*time.Second, 60*time.Second),
)
```

### Subscribing to topics

Subscribe returns a `*Subscription` with channels for receiving values and errors. Multiple subscriptions to the same topic share a single server-side subscription.

```go
sub := client.Subscribe("lists/my-list", nil)
defer sub.Unsubscribe()

for val := range sub.Values() {
    fmt.Println("new value:", val)
}
```

Topics can take parameters:

```go
sub := client.Subscribe("lists/my-list", topical.Params{"user_id": "123"})
```

### Typed subscriptions

Use the generic `Subscribe` function to automatically unmarshal values into a struct:

```go
type TodoList struct {
    Items map[string]Item `json:"items"`
    Order []string        `json:"order"`
}

sub := topical.Subscribe[TodoList](client, "lists/my-list", nil)
defer sub.Unsubscribe()

for list := range sub.Values() {
    fmt.Printf("got %d items\n", len(list.Items))
}
```

### Execute (RPC)

Send a request and wait for a response. The context controls the timeout:

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()

result, err := client.Execute(ctx, "lists/my-list", "add_item", []any{"buy milk"}, nil)
```

### Notify (fire-and-forget)

Send a one-way message with no response:

```go
err := client.Notify("lists/my-list", "mark_done", []any{"item-id"}, nil)
```

### Connection state

```go
fmt.Println(client.State()) // "connected", "connecting", or "disconnected"

stateSub := client.StateChanges()
defer stateSub.Close()

for s := range stateSub.C() {
    fmt.Println("state changed:", s)
}
```

### Error handling

Check for subscription errors on the `Err()` channel:

```go
select {
case val := <-sub.Values():
    handleValue(val)
case err := <-sub.Err():
    handleError(err)
}
```

Operations return `topical.ErrNotConnected` when the client is disconnected.
