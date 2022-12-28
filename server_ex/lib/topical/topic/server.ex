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
  Invoked when a client has executed an action.

  This callback is optional. If one is not implemented, the topic will fail if an action is
  executed.
  """
  @callback handle_execute(action :: term(), args :: tuple(), topic :: %Topic{}) ::
              {:ok, term(), %Topic{}}

  @doc """
  Invoked when a client has sent a notification.

  This callback is optional. If one is not implemented, the topic will fail if a notification is
  received.
  """
  @callback handle_notify(action :: term(), args :: tuple(), topic :: %Topic{}) ::
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
    {:ok, topic} = state.module.init(init_arg)
    state = Map.put(state, :topic, topic)
    {:noreply, state, timeout(state)}
  end

  @impl true
  def handle_continue({:subscribe, ref, pid}, state) do
    send(pid, {:reset, ref, state.topic.value})
    {:noreply, state, timeout(state)}
  end

  @impl true
  def handle_cast({:unsubscribe, ref}, state) do
    state = remove_subscriber(state, ref)
    Process.demonitor(ref)
    {:noreply, state, timeout(state)}
  end

  @impl true
  def handle_cast({:notify, action, args}, state) do
    case state.module.handle_notify(action, args, state.topic) do
      {:ok, topic} ->
        state = process(state, topic)
        {:noreply, state, timeout(state)}
    end
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    ref = Process.monitor(pid)
    state = put_in(state.subscribers[ref], pid)
    {:reply, ref, state, {:continue, {:subscribe, ref, pid}}}
  end

  @impl true
  def handle_call({:execute, action, args}, _from, state) do
    case state.module.handle_execute(action, args, state.topic) do
      {:ok, reply, topic} ->
        state = process(state, topic)
        {:reply, reply, state, timeout(state)}
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
      {:ok, topic} ->
        state = process(state, topic)
        {:noreply, state, timeout(state)}
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
    value = Enum.reduce(topic.updates, state.topic.value, &Update.apply(&2, &1))
    # TODO: check that value and topic.value are equal?
    notify_subscribers(state.subscribers, topic.updates)

    topic =
      state.topic
      |> Map.put(:state, topic.state)
      |> Map.put(:value, value)

    Map.put(state, :topic, topic)
  end

  defp notify_subscribers(subscribers, updates) do
    Enum.each(subscribers, fn {ref, pid} ->
      send(pid, {:updates, ref, updates})
    end)
  end

  defp remove_subscriber(state, ref) do
    {_, state} = pop_in(state.subscribers[ref])
    state
  end
end
