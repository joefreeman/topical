# Topical/Examples → Todo

This is a todo list example. Each list is represented by an instance of the 'list' topic, and a separate 'lists' topic
maintains an index of the available lists.

State is persisted to files (as long as the topic is shut down cleanly).

For illustrative purposes, two web servers are started: a Cowboy server on 3001, and a Bandit/Plug server on 3002.

# Running the example

```bash
iex -S mix
```

Open http://localhost:3001 or http://localhost:3002.
