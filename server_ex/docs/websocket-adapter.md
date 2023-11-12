# WebSocket adapter

Rather than interacting with with the `Topical` API directly, you can expose Topical from your web
server. Separate adapters exist for Cowboy and WebSock (for use with Plug and Bandit).

In both cases, the Topical registry must be specified (`Todo.Registry` in the examples below).

## Cowboy adapter

If you're using Cowboy, the adapter can be added to your routes:

```elixir
:cowboy_router.compile([
  {:_,
   [
     # ...
     {"/socket", Topical.Adapters.Cowboy.WebsocketHandler, registry: Todo.Registry}
   ]}
])
```

## WebSock adapter

The WebSock adapter is compatible with Plug (and Bandit):

```elixir
defmodule Router do
  use Plug.Router

  plug :match
  plug :dispatch

  # ...

  get "/socket" do
    conn
    |> WebSockAdapter.upgrade(
      Topical.Adapters.Plug.WebSockServer,
      [registry: Todo.Registry],
      timeout: 60_000
    )
    |> halt()
  end

  # ...
end
```

## Context

Optionally, an `init` function can be passed, which will be called before the connection is
upgraded. It will be passed the Cowboy request or Plug conn, and must return `{:ok, context}`. The
`context` will then be passed to the topic. This can be useful for authentication: for
unauthenticated users, return an error result to prevent the socket getting established; for
authenticated users, include the user ID in the context so it can be used for
authorisation/identification within a topic.

## Client

You can now connect to Topical from a [JavaScript client](javascript-client.md).
