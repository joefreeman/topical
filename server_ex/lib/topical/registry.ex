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

  defp build_routes(modules) do
    Enum.map(modules, fn module ->
      route =
        module.route
        |> String.split("/")
        |> Enum.map(fn
          ":" <> atom -> String.to_atom(atom)
          part -> part
        end)

      {route, module}
    end)
  end

  defp resolve_route(route, routes) do
    parts = String.split(route, "/")

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

  def get_topic(name, route) do
    {registry_name, supervisor_name} = resolve_names(name)

    case Registry.lookup(registry_name, route) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        {:ok, routes} = Registry.meta(registry_name, :routes)

        case resolve_route(route, routes) do
          {module, params} ->
            spec =
              {Topical.Topic.Server,
               name: {:via, Registry, {registry_name, route}},
               id: route,
               module: module,
               init_arg: params}

            case DynamicSupervisor.start_child(supervisor_name, spec) do
              {:ok, pid} -> {:ok, pid}
              {:error, reason} -> {:error, reason}
            end

          nil ->
            {:error, :not_found}
        end
    end
  end

  defp resolve_names(name) when is_atom(name) do
    registry_name = Module.concat(name, "Registry")
    supervisor_name = Module.concat(name, "Supervisor")
    {registry_name, supervisor_name}
  end
end
