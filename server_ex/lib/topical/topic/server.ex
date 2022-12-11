defmodule Topical.Topic.Server do
  use GenServer, restart: :transient

  alias Topical.Topic.Utils

  def start_link(options) do
    {module, options} = Keyword.pop!(options, :module)
    {arguments, options} = Keyword.pop!(options, :arguments)
    GenServer.start_link(__MODULE__, {module, arguments}, options)
  end

  @impl true
  def init({module, arguments}) do
    {:ok,
     %{
       module: module,
       topic: nil,
       subscribers: %{},
       timeout: 10_000
     }, {:continue, {:init, arguments}}}
  end

  @impl true
  def handle_continue({:init, arguments}, state) do
    {:ok, topic} = state.module.init(arguments)
    state = Map.put(state, :topic, topic)
    {:noreply, state, timeout(state)}
  end

  @impl true
  def handle_continue({:subscribe, ref, pid}, state) do
    send(pid, {:refresh, ref, state.topic.value})
    {:noreply, state, timeout(state)}
  end

  @impl true
  def handle_cast({:unsubscribe, ref}, state) do
    state = remove_subscriber(state, ref)
    Process.demonitor(ref)
    {:noreply, state, timeout(state)}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    ref = Process.monitor(pid)
    state = put_in(state.subscribers[ref], pid)
    {:reply, ref, state, {:continue, {:subscribe, ref, pid}}}
  end

  @impl true
  def handle_call({:execute, request}, _from, state) do
    case state.module.handle_execute(request, state.topic) do
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
    value = Enum.reduce(topic.updates, state.topic.value, &Utils.apply_update/2)
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
