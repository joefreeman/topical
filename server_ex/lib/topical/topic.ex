defmodule Topical.Topic do
  @moduledoc """
  This module provides functions for instantiating and manipulating topic state.

  The state of a topic is composed of a _value_, observed by subscribed clients, and also _hidden_
  internal state, which can be used to share state between calls. The value must only be
  manipulated by the helper functions (which track the individual updates). The hidden `state` can
  be modified directly.

  This module also contains a macro - `use`-ing it sets up a topic server:

      defmodule MyApp.Topics.List do
        use Topical.Topic, route: ["lists", :list_id]

        # Initialise the topic
        def init(params) do
          list_id = Keyword.fetch!(params, :list_id)

          value = %{items: %{}, order: []} # exposed 'value' of the topic
          state = %{list_id: list_id} # hidden server state
          topic = Topic.new(value, state)

          {:ok, topic}
        end

        # Optionally, handle subscribe
        def handle_subscribe(topic, _context) do
          {:ok, topic}
        end

        # Optionally, handle unsubscribe
        def handle_unsubscribe(topic, _context) do
          {:ok, topic}
        end

        # Optionally, handle capture
        def handle_capture(topic, _context) do
          {:ok, topic}
        end

        # Optionally, handle execution of an action
        def handle_execute("add_item", {text}, topic, _context) do
          id = Integer.to_string(:erlang.system_time())

          # Update the topic by putting the item in 'items', and appending the id to 'order'
          topic =
            topic
            |> Topic.set([:items, id], %{text: text, done: false})
            |> Topic.insert([:order], id)

          # Return the result (the 'id'), and the updated topic
          {:ok, id, topic}
        end

        # Optionally, handle a notification (an action without a result)
        def handle_notify("update_text", {id, text}, topic, _context) do
          topic  = Topic.set(topic, [:items, id, :text], text)
          {:ok, topic}
        end

        # Optionally, handle Erlang messages
        def handle_info({:done, id}, topic) do
          topic  = Topic.set(topic, [:items, id, :done], true)
          {:ok, topic}
        end

        # Optionally, handle the topic being terminated (e.g., once clients have disconnected)
        def terminate(_reason, topic) do
          # ...
        end
      end
  """

  alias Topical.Topic.Update

  @doc false
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Topical.Topic.Server

      alias Topical.Topic

      def route() do
        unquote(Keyword.fetch!(opts, :route))
      end

      def handle_subscribe(topic, _context) do
        {:ok, topic}
      end

      def handle_unsubscribe(topic, _context) do
        {:ok, topic}
      end

      def handle_capture(topic, _context) do
        {:ok, topic}
      end

      def handle_execute(_action, _args, _topic, _context) do
        raise "no handle_execute/4 implemented"
      end

      def handle_notify(_action, _args, _topic, _context) do
        raise "no handle_notify/4 implemented"
      end

      def handle_info(_msg, topic) do
        # TODO: log warning?
        {:ok, topic}
      end

      def terminate(_reason, _topic) do
        :ok
      end

      defoverridable handle_subscribe: 2,
                     handle_unsubscribe: 2,
                     handle_capture: 2,
                     handle_execute: 4,
                     handle_notify: 4,
                     handle_info: 2,
                     terminate: 2
    end
  end

  defstruct [:state, :value, :updates]

  @doc """
  Instantiates a new instance of a topic.

  `value` is the initial value of the client-visible state. `state` is the 'hidden' internal state.
  """
  def new(value, state \\ nil) do
    %__MODULE__{value: value, state: state, updates: []}
  end

  defp update(topic, update) do
    topic_value = Update.apply(topic.value, update)

    topic
    |> Map.update!(:updates, &[update | &1])
    |> Map.put(:value, topic_value)
  end

  @doc """
  Updates the topic by setting the `value` at the `path`.

      %{foo: %{bar: 2}}
      |> Topic.new()
      |> Topic.set([:foo, :bar], 3)
      |> Map.fetch!(:value)
      #=> %{foo: %{bar: 3}}
  """
  def set(topic, path, value) do
    update(topic, {:set, path, value})
  end

  @doc """
  Updates the topic by unsetting the `key` of the object at the `path`.

      %{foo: %{bar: 2}}
      |> Topic.new()
      |> Topic.unset([:foo], :bar)
      |> Map.fetch!(:value)
      #=> %{foo: %{}}
  """
  def unset(topic, path, key) do
    update(topic, {:unset, path, key})
  end

  @doc """
  Updates the topic by inserting the specified `values` into the array at the `path`, at the
  `index` (or append them to the end, if no `index` is specified).

  If `value` is a list, all the items will be added (to add a list as a single item, wrap it in a
  list).

      %{foo: %{bar: [1, 4]}}
      |> Topic.new()
      |> Topic.insert([:foo, :bar], 1, [2, 3])
      |> Map.fetch!(:value)
      #=> %{foo: %{bar: [1, 2, 3, 4]}}
  """
  def insert(topic, path, index \\ nil, value) do
    value = List.wrap(value)

    if Enum.any?(value) do
      update(topic, {:insert, path, index, value})
    else
      topic
    end
  end

  @doc """
  Updates the topic be deleting `count` values from the array at the `path`, from the `index`.

      %{foo: %{bar: [1, 2, 3, 4]}}
      |> Topic.new()
      |> Topic.delete([:foo, :bar], 2)
      |> Map.fetch!(:value)
      #=> %{foo: %{bar: [1, 2, 4]}}
  """
  def delete(topic, path, index, count \\ 1) do
    update(topic, {:delete, path, index, count})
  end

  @doc """
  Updates the opic by merging `value` into `path`.

      %{foo: %{bar: %{a: 1, b: 2}}}
      |> Topic.new()
      |> Topic.merge([:foo, :bar], %{b: 3, c: 4})
      |> Map.fetch!(:value)
      #=> %{foo: %{bar: %{a: 1, b: 3, c: 4}}}
  """
  def merge(topic, path, value) do
    update(topic, {:merge, path, value})
  end
end
