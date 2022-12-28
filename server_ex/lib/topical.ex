defmodule Topical do
  @moduledoc """
  This module provides the high level interface for interacting with topics. Primarily for
  subscribing (and unsubscribing), but also for sending requests.

  After subscribing, a client will initially receive a `{:reset, ref, value}` message, and then
  subsequent `{:updates, ref, updates}` messages when the value of the topic changes, where
  `updates` is a list with each item being one of:

   - `{:set, path, value}`: the `value` has been set at the `path`.
   - `{:unset, path, key}`: the `key` has been unset from the object at the `path`.
   - `{:insert, path, index, values}`: the `values` have been inserted into the array at the `path`.
   - `{:delete, path, index, count}`: `count` values have been deleted from the array at the `path`, from the position `index`.

  A client can interact directly with a topic by _executing_ actions (which returns a result), or
  by _notifying_ (without waiting for a result). These are analogous to `GenServer.call/3` and
  `GenServer.cast/2`. Be aware that a topic is blocked while processing a request.
  """

  alias Topical.Registry

  @doc """
  Returns a specification to start a Topical registry under a supervisor.
  """
  def child_spec(options) do
    %{
      id: Keyword.get(options, :server, Topical),
      start: {Registry, :start_link, [options]},
      type: :supervisor
    }
  end

  @doc """
  Subscribes to the specified `topic` (in the specified `registry`).

  Returns `{:ok, ref}`, where the `ref` is a reference to the subscription.

  The `pid` will be send messages, as described above.

  ## Example

      Topical.subscribe(MyApp.Topical, "lists/foo", self())
      #=> {:ok, #Reference<0.4021726225.4145020932.239110>}

  """
  def subscribe(registry, topic, pid) do
    with {:ok, server} <- Registry.get_topic(registry, topic) do
      # TODO: monitor/link server?
      {:ok, GenServer.call(server, {:subscribe, pid})}
    end
  end

  @doc """
  Unsubscribes from a `topic` (in the specified `registry`).

  ## Example

      Topical.unsubscribe(MyApp.Topical, "lists/foo", ref)

  """
  def unsubscribe(registry, topic, ref) do
    # TODO: don't start server if not running
    with {:ok, server} <- Registry.get_topic(registry, topic) do
      GenServer.cast(server, {:unsubscribe, ref})
    end
  end

  @doc """
  Executes an action in a `topic`.

  ## Example

      Topical.execute(MyApp.Topical, "lists/foo", "add_item", {"Test", false})
      #=> {:ok, "item123"}

  """
  def execute(registry, topic, action, args \\ {}) do
    with {:ok, server} <- Registry.get_topic(registry, topic) do
      {:ok, GenServer.call(server, {:execute, action, args})}
    end
  end

  @doc """
  Send a notification to a registry.

  This is similar to `execute/4`, except no result is waited for.

  ## Example

      Topical.notify(MyApp.Topical, "lists/foo", "update_done", {"item123", true})
      #=> :ok

  """
  def notify(registry, topic, action, args \\ {}) do
    with {:ok, server} <- Registry.get_topic(registry, topic) do
      GenServer.cast(server, {:notify, action, args})
    end
  end
end
