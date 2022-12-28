# Introduction

Topical is a library for defining and serving _topics_. A topic is a value that can be efficiently
observed in real-time by connected clients. The server-side implementation takes care of defining
how to intialise the state, and then how to keep it updated.

Multiple clients can subscribe to an instance of a topic - instances are identifier by a path,
which matches the route defined by a topic. Multiple instances of a topic can exist by using route
placeholders.

Topical takes care of starting topic instances as needed, and stopping them once all clients have
disconnected.

## Uses

Topics are implemented in Elixir, and behave somewhat like GenServers - the main difference being
that their state is easily observable by clients. There's more flexibility on the client side - the
main benefit comes from using the JavaScript (and React) client (and Cowboy WebSocket adpater) to
observe the state, but it's also possible to use the Elixir API.

There's a certain amount of flexibility in how topics are implemented. They can be be used to track
ephemeral state - for example user presence, or cursor positions. They can be backed by simple
mechanisms like a file or file-based database. Or they can sit in front of an RDBMS (e.g., utilising
Postgres notification channels), providing real-time cached views. Or they can be used to implement
the event sourcing pattern.
