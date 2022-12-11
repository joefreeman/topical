defmodule Topical.Registry do
  def start_link(options) do
    name = Keyword.fetch!(options, :name)
    topics = Keyword.fetch!(options, :topics)

    {table_name, registry_name, supervisor_name} = resolve_names(name)
    initialise_table(table_name, topics)

    Supervisor.start_link(
      [
        {Registry, name: registry_name, keys: :unique},
        {DynamicSupervisor, name: supervisor_name, strategy: :one_for_one}
      ],
      strategy: :one_for_all,
      name: name
    )
  end

  def get_topic(name, {topic, arguments}) do
    {table_name, registry_name, supervisor_name} = resolve_names(name)

    with {:ok, module} <- lookup_topic(table_name, topic) do
      key = {module, arguments}

      case Registry.lookup(registry_name, key) do
        [{pid, _}] ->
          {:ok, pid}

        [] ->
          spec =
            {Topical.Topic.Server,
             name: {:via, Registry, {registry_name, key}},
             id: key,
             module: module,
             arguments: arguments}

          case DynamicSupervisor.start_child(supervisor_name, spec) do
            {:ok, pid} -> {:ok, pid}
            {:error, reason} -> {:error, reason}
          end
      end
    end
  end

  defp resolve_names(name) do
    table_name = Module.concat(name, :topics)
    registry_name = Module.concat(name, :registry)
    supervisor_name = Module.concat(name, :supervisor)
    {table_name, registry_name, supervisor_name}
  end

  defp initialise_table(table_name, topics) do
    :ets.new(table_name, [:named_table, read_concurrency: true])
    :ets.insert(table_name, Enum.map(topics, &{&1.name, &1}))
  end

  defp lookup_topic(table_name, topic) do
    case :ets.lookup(table_name, topic) do
      [] -> {:error, :not_found}
      [{^topic, module}] -> {:ok, module}
    end
  end
end
