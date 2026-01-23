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

  Returns `{:ok, ref, server}`, where `ref` is a reference to the subscription and
  `server` is the topic server PID (used for unsubscribing).

  The `pid` will be sent messages, as described above.

  ## Options

    * `params` - Optional map of params to pass to the topic (default: `%{}`).
      These are merged with route params and passed to `connect/2` and `init/1`.
      Topics with different param values are separate instances and do not share state.

  ## Example

      Topical.subscribe(MyApp.Topical, ["lists", "foo"], self())
      #=> {:ok, #Reference<0.4021726225.4145020932.239110>, #PID<0.123.0>}

  """
  def subscribe(registry, topic, pid, context \\ nil, params \\ %{}) do
    with {:ok, module, all_params, topic_key} <-
           Registry.resolve_topic(registry, topic, context, params),
         {:ok, server} <- Registry.get_topic(registry, module, all_params, topic_key) do
      # TODO: monitor/link server?
      ref = GenServer.call(server, {:subscribe, pid, context})
      {:ok, ref, server}
    end
  end

  @doc """
  Unsubscribes from a topic.

  Takes the `server` PID and `ref` returned from `subscribe/5`.

  ## Example

      {:ok, ref, server} = Topical.subscribe(MyApp.Topical, ["lists", "foo"], self())
      Topical.unsubscribe(server, ref)

  """
  def unsubscribe(server, ref) do
    GenServer.cast(server, {:unsubscribe, ref})
  end

  @doc """
  Captures the state of the `topic` (in the specified `registry`) without subscribing.

  ## Options

    * `params` - Optional map of params to pass to the topic (default: `%{}`).

  ## Example

      Topical.capture(MyApp.Topical, ["lists", "foo"])
      # => {:ok, %{items: %{}, order: []}}
  """
  def capture(registry, topic, context \\ nil, params \\ %{}) do
    with {:ok, module, all_params, topic_key} <-
           Registry.resolve_topic(registry, topic, context, params),
         {:ok, server} <- Registry.get_topic(registry, module, all_params, topic_key) do
      {:ok, GenServer.call(server, {:capture, context})}
    end
  end

  @doc """
  Executes an action in a `topic`.

  ## Options

    * `params` - Optional map of params to pass to the topic (default: `%{}`).

  ## Example

      Topical.execute(MyApp.Topical, ["lists", "foo"], "add_item", {"Test", false})
      #=> {:ok, "item123"}

  """
  def execute(registry, topic, action, args \\ {}, context \\ nil, params \\ %{}) do
    with {:ok, module, all_params, topic_key} <-
           Registry.resolve_topic(registry, topic, context, params),
         {:ok, server} <- Registry.get_topic(registry, module, all_params, topic_key) do
      {:ok, GenServer.call(server, {:execute, action, args, context})}
    end
  end

  @doc """
  Send a notification to a registry.

  This is similar to `execute/4`, except no result is waited for.

  ## Options

    * `params` - Optional map of params to pass to the topic (default: `%{}`).

  ## Example

      Topical.notify(MyApp.Topical, ["lists", "foo"], "update_done", {"item123", true})
      #=> :ok

  """
  def notify(registry, topic, action, args \\ {}, context \\ nil, params \\ %{}) do
    with {:ok, module, all_params, topic_key} <-
           Registry.resolve_topic(registry, topic, context, params),
         {:ok, server} <- Registry.get_topic(registry, module, all_params, topic_key) do
      GenServer.cast(server, {:notify, action, args, context})
    end
  end
end
