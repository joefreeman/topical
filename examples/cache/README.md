# Topical/Examples → Cache

This is an example of how to use Topical as an incremental cache.

A topic is used to represent the state of the cache (in this case, a 'widget'). When the corresponding URL is first loaded, an artificial delay simulates the state being loaded. Then subsequent requests are served immediately. The state (in this case, a quantity value) gets updated without needing to reinitialise state.

## What's an incremental cache?

Typically a cache will contain snapshots of state that get invalidated (manually, or based on some strategy). An incremental loads its state and then keeps itself up-to-date (by subscribing to an event stream, or similar).

# Running the example

```bash
iex -S mix
```

Open, e.g., http://localhost:3000/topics/widgets/a
