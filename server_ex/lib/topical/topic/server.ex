defmodule Topical.Topic.Server do
  alias Topical.Topic

  @moduledoc """
  This module defines the bahaviour of a topic.

  See `Topical.Topic` for a usage example.
  """

  @doc """
  Invoked when the topic is started to get the initial state.

  `params` are the values associated with the placeholders in the route.
  """
  @callback init(params :: [...]) :: {:ok, %Topic{}}

  @doc """
  Invoked before a client subscribes (but after initialisation).

  This callback can be used to update the topic, for example (in combination with
  `handle_unsubscribe`) to track connected users.

  This callback is optional.
  """
  @callback handle_subscribe(topic :: %Topic{}, context :: any()) :: {:ok, %Topic{}}

  @doc """
  Invoked after a client unsubscribes (either explicitly or because the process dies).

  This callback is optional.
  """
  @callback handle_unsubscribe(topic :: %Topic{}, context :: any()) :: {:ok, %Topic{}}

  @doc """
  Invoked before state is captured (after initialisation).

  This callback is optional.
  """
  @callback handle_capture(topic :: %Topic{}, context :: any()) :: {:ok, %Topic{}}

  @doc """
  Invoked when a client has executed an action.

  This callback is optional. If one is not implemented, the topic will fail if an action is
  executed.
  """
  @callback handle_execute(action :: term(), args :: tuple(), topic :: %Topic{}, context :: any()) ::
              {:ok, term(), %Topic{}}

  @doc """
  Invoked when a client has sent a notification.

  This callback is optional. If one is not implemented, the topic will fail if a notification is
  received.
  """
  @callback handle_notify(action :: term(), args :: tuple(), topic :: %Topic{}, context :: any()) ::
              {:ok, %Topic{}}

  @doc """
  Invoked to handle other messages.

  This callback is optional.
  """
  @callback handle_info(msg :: term, topic :: %Topic{}) :: {:ok, %Topic{}}

  @doc """
  Invoked when a topic has been stopped.

  This callback is optional.
  """
  @callback terminate(reason :: term, topic :: %Topic{}) :: term

  use GenServer, restart: :transient

  alias Topical.Topic.Update

  @doc """
  Starts a topic server process linked to the current process.

  ## Options

    * `:module` - the module that implements the topic behaviour.
    * `:init_arg` - the argument passed to the topic's `init` callback.
  """
  def start_link(options) do
    {module, options} = Keyword.pop!(options, :module)
    {init_arg, options} = Keyword.pop!(options, :init_arg)
    GenServer.start_link(__MODULE__, {module, init_arg}, options)
  end

  @impl true
  def init({module, init_arg}) do
    {:ok,
     %{
       module: module,
       topic: nil,
       subscribers: %{},
       timeout: 10_000
     }, {:continue, {:init, init_arg}}}
  end

  @impl true
  def handle_continue({:init, init_arg}, state) do
    case state.module.init(init_arg) do
      {:ok, %Topic{} = topic} ->
        state = Map.put(state, :topic, topic)
        {:noreply, state, timeout(state)}

      other ->
        raise "init/1 returned unexpected result - expected `{:ok, topic}`; got: #{inspect(other)}"
    end
  end

  @impl true
  def handle_continue({:subscribe, ref, pid}, state) do
    send(pid, {:reset, ref, state.topic.value})
    {:noreply, state, timeout(state)}
  end

  @impl true
  def handle_cast({:unsubscribe, ref}, state) do
    Process.demonitor(ref)
    state = remove_subscriber(state, ref)
    {:noreply, state, timeout(state)}
  end

  @impl true
  def handle_cast({:notify, action, args, context}, state) do
    case state.module.handle_notify(action, args, state.topic, context) do
      {:ok, %Topic{} = topic} ->
        state = process(state, topic)
        {:noreply, state, timeout(state)}

      other ->
        raise "handle_notify/4 returned unexpected result - expected `{:ok, topic}`; got: #{inspect(other)}"
    end
  end

  @impl true
  def handle_call({:subscribe, pid, context}, _from, state) do
    case state.module.handle_subscribe(state.topic, context) do
      {:ok, %Topic{} = topic} ->
        state = process(state, topic)
        ref = Process.monitor(pid)
        subscriber = %{pid: pid, context: context}
        state = put_in(state.subscribers[ref], subscriber)
        {:reply, ref, state, {:continue, {:subscribe, ref, pid}}}

      other ->
        raise "handle_subscribe/2 returned unexpected result - expected `{:ok, topic}`; got: #{inspect(other)}"
    end
  end

  @impl true
  def handle_call({:capture, context}, _from, state) do
    case state.module.handle_capture(state.topic, context) do
      {:ok, %Topic{} = topic} ->
        state = process(state, topic)
        {:reply, topic.value, state, timeout(state)}

      other ->
        raise "handle_capture/2 returned unexpected result - expected `{:ok, topic}`; got: #{inspect(other)}"
    end
  end

  @impl true
  def handle_call({:execute, action, args, context}, _from, state) do
    case state.module.handle_execute(action, args, state.topic, context) do
      {:ok, reply, %Topic{} = topic} ->
        state = process(state, topic)
        {:reply, reply, state, timeout(state)}

      other ->
        raise "handle_execute/4 returned unexpected result - expected `{:ok, reply, topic}`; got: #{inspect(other)}"
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    state = remove_subscriber(state, ref)
    {:noreply, state, timeout(state)}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(msg, state) do
    case state.module.handle_info(msg, state.topic) do
      {:ok, %Topic{} = topic} ->
        state = process(state, topic)
        {:noreply, state, timeout(state)}

      other ->
        raise "handle_info/2 returned unexpected result - expected `{:ok, topic}`; got: #{inspect(other)}"
    end
  end

  @impl true
  def terminate(reason, state) do
    state.module.terminate(reason, state.topic)
  end

  defp timeout(state) do
    if Enum.any?(state.subscribers) do
      :infinity
    else
      state.timeout
    end
  end

  defp process(state, topic) do
    updates = Enum.reverse(topic.updates)
    value = Enum.reduce(updates, state.topic.value, &Update.apply(&2, &1))

    if value != topic.value do
      raise "topic has unexpected value - expected: #{inspect(value)}; got: #{inspect(topic.value)}"
    end

    # TODO: check that value and topic.value are equal?
    notify_subscribers(state.subscribers, updates)

    Map.put(state, :topic, Topic.new(value, topic.state))
  end

  defp notify_subscribers(subscribers, updates) do
    Enum.each(subscribers, fn {ref, subscriber} ->
      send(subscriber.pid, {:updates, ref, updates})
    end)
  end

  defp remove_subscriber(state, ref) do
    {subscriber, state} = pop_in(state.subscribers[ref])

    case state.module.handle_unsubscribe(state.topic, subscriber.context) do
      {:ok, %Topic{} = topic} ->
        process(state, topic)

      other ->
        raise "handle_unsubscribe/2 returned unexpected result - expected `{:ok, topic}`; got: #{inspect(other)}"
    end
  end
end
