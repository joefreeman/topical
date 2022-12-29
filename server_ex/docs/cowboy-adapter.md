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

## Context

Optionally, an `init` function can be passed, which will be called before the connection is
upgraded. It will be passed the Cowboy request, and must return `{:ok, context}`. The `context`
will then be passed to the topic. This can be useful for authentication: for unauthenticated users,
return an error result to prevent the socket getting established; for authenticated users, include
the user ID in the context so it can be used for authorisation/identification within a topic.

## Client

You can now connect to Topical from a [JavaScript client](javascript-client.md).
