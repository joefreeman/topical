# Topical/Examples → Cache

This is an example of how to use Topical as an incremental cache.

A topic is used to represent the state of the cache (in this case, a 'widget'). When the corresponding URL is first loaded, an artificial delay simulates the state being loaded. Then subsequent requests are served immediately. The state (in this case, a quantity value) gets updated without needing to reinitialise state.

# Running the example

```bash
iex -S mix
```

Open, e.g., http://localhost:3000/topics/widgets/a
