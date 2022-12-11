defmodule Topical do
  alias Topical.Registry

  def child_spec(options) do
    %{
      id: Keyword.get(options, :server, Topical),
      start: {Registry, :start_link, [options]},
      type: :supervisor
    }
  end

  def subscribe(registry, topic, pid) do
    with {:ok, server} <- Registry.get_topic(registry, topic) do
      GenServer.call(server, {:subscribe, pid})
    end
  end

  def unsubscribe(registry, topic, ref) do
    # TODO: don't start server if not running
    with {:ok, server} <- Registry.get_topic(registry, topic) do
      GenServer.cast(server, {:unsubscribe, ref})
    end
  end

  def execute(registry, topic, request) do
    with {:ok, server} <- Registry.get_topic(registry, topic) do
      GenServer.call(server, {:execute, request})
    end
  end
end
