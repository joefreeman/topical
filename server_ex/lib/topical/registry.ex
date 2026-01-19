defmodule Topical.Registry do
  @moduledoc false

  def start_link(options) do
    name = Keyword.fetch!(options, :name)
    routes = options |> Keyword.fetch!(:topics) |> build_routes()

    {registry_name, supervisor_name} = resolve_names(name)

    Supervisor.start_link(
      [
        {Registry, name: registry_name, keys: :unique, meta: [routes: routes]},
        {DynamicSupervisor, name: supervisor_name, strategy: :one_for_one}
      ],
      strategy: :one_for_all,
      name: name
    )
  end

  defp parse_route(route) do
    if is_binary(route) do
      route
      |> String.split("/")
      |> Enum.map(fn
        ":" <> atom -> String.to_atom(atom)
        part -> URI.decode(part)
      end)
    else
      route
    end
  end

  defp build_routes(modules) do
    Enum.map(modules, &{parse_route(&1.route()), &1})
  end

  defp resolve_route(route, routes) do
    parts =
      if is_binary(route) do
        route
        |> String.split("/")
        |> Enum.map(&URI.decode/1)
      else
        route
      end

    Enum.find_value(routes, fn {route, module} ->
      match = match_route(parts, route)

      if match do
        {module, match}
      end
    end)
  end

  defp match_route(parts, route) do
    if length(parts) == length(route) do
      parts
      |> Enum.zip(route)
      |> Enum.reduce_while([], fn {part, route_part}, params ->
        cond do
          is_atom(route_part) ->
            {:cont, Keyword.put(params, route_part, part)}

          part == route_part ->
            {:cont, params}

          true ->
            {:halt, nil}
        end
      end)
    else
      nil
    end
  end

  @doc """
  Looks up an existing topic without starting it.

  Returns `{:ok, pid}` if the topic is running, or `{:error, :not_running}` if not.
  """
  def lookup_topic(name, route) do
    {registry_name, _supervisor_name} = resolve_names(name)

    case Registry.lookup(registry_name, route) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_running}
    end
  end

  @doc """
  Gets or starts a topic, after checking authorization.

  Returns `{:ok, pid}` if authorized and the topic is running (or was started),
  or `{:error, reason}` if authorization fails or the topic cannot be started.
  """
  def get_topic(name, route, context) do
    {registry_name, supervisor_name} = resolve_names(name)
    {:ok, routes} = Registry.meta(registry_name, :routes)

    case resolve_route(route, routes) do
      {module, params} ->
        case module.authorize(params, context) do
          :ok ->
            case Registry.lookup(registry_name, route) do
              [{pid, _}] ->
                {:ok, pid}

              [] ->
                spec =
                  {Topical.Topic.Server,
                   name: {:via, Registry, {registry_name, route}},
                   id: route,
                   module: module,
                   init_arg: params}

                case DynamicSupervisor.start_child(supervisor_name, spec) do
                  {:ok, pid} -> {:ok, pid}
                  {:error, {:already_started, pid}} -> {:ok, pid}
                  {:error, reason} -> {:error, reason}
                end
            end

          {:error, reason} ->
            {:error, reason}
        end

      nil ->
        {:error, :not_found}
    end
  end

  defp resolve_names(name) when is_atom(name) do
    registry_name = Module.concat(name, "Registry")
    supervisor_name = Module.concat(name, "Supervisor")
    {registry_name, supervisor_name}
  end
end
