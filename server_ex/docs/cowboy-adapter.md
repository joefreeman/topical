# Cowboy adapter

Rather than interacting with with the `Topical` API directly, you can simply expose Topical from
your web server. If you're using Cowboy, this can be easily achieved using the Cowboy WebSocket
handler adapter:

```elixir
:cowboy_router.compile([
  {:_,
   [
     # ...
     {"/socket", Topical.Adapters.Cowboy.WebsocketHandler, registry: Todo.Registry}
   ]}
])
```

The Topical registry must be specified.

You can now connect to Topical from a [JavaScript client](javascript-client.md).
