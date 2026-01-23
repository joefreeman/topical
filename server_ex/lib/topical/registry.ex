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
  Resolves a route, calls connect, and computes the topic key.

  Returns `{:ok, module, final_params, topic_key}` or `{:error, reason}`.

  The returned values can be passed to `get_topic/4` to avoid resolving twice.

  The `connect/2` callback is called with the merged params and context, and may
  return modified params. The topic key is computed from the final params
  (excluding route params, which are implicit in the route).
  """
  def resolve_topic(name, route, context, request_params \\ %{}) do
    {registry_name, _supervisor_name} = resolve_names(name)
    {:ok, routes} = Registry.meta(registry_name, :routes)

    case resolve_route(route, routes) do
      {module, route_params} ->
        case normalize_params(request_params, module.params()) do
          {:ok, normalized_params} ->
            all_params = Keyword.merge(route_params, normalized_params)

            case module.connect(all_params, context) do
              {:ok, final_params} ->
                # Topic key is route + non-route params (route params are implicit in the route)
                non_route_params = Keyword.drop(final_params, Keyword.keys(route_params))
                topic_key = {route, non_route_params}
                {:ok, module, final_params, topic_key}

              {:error, reason} ->
                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Gets or starts a topic.

  Accepts the resolved values from `resolve_topic/4`. Authorization has already
  been checked by `resolve_topic/4` via the `connect/2` callback.

  Returns `{:ok, pid}` if the topic is running (or was started),
  or `{:error, reason}` if the topic cannot be started.
  """
  def get_topic(name, module, all_params, topic_key) do
    {registry_name, supervisor_name} = resolve_names(name)

    case Registry.lookup(registry_name, topic_key) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        spec =
          {Topical.Topic.Server,
           name: {:via, Registry, {registry_name, topic_key}},
           id: topic_key,
           module: module,
           init_arg: all_params}

        case DynamicSupervisor.start_child(supervisor_name, spec) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  # Normalizes request params against declared params:
  # - Filters to only declared param names (ignores unknown params)
  # - Converts string keys to atoms (safe because we only use declared names)
  # - Normalizes empty strings to nil
  # - Applies default values for missing params
  # - Returns {:ok, sorted_keyword_list} or {:error, {:invalid_param, name}}
  defp normalize_params(request_params, declared_params) do
    declared_params
    |> Enum.reduce_while({:ok, []}, fn {name, default}, {:ok, acc} ->
      # Try both atom and string key
      value =
        case Map.get(request_params, name) do
          nil -> Map.get(request_params, Atom.to_string(name))
          v -> v
        end

      case value do
        nil -> {:cont, {:ok, [{name, default} | acc]}}
        "" -> {:cont, {:ok, [{name, default} | acc]}}
        v when is_binary(v) -> {:cont, {:ok, [{name, v} | acc]}}
        _ -> {:halt, {:error, {:invalid_param, name}}}
      end
    end)
    |> case do
      {:ok, params} -> {:ok, Enum.sort_by(params, fn {name, _} -> name end)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_names(name) when is_atom(name) do
    registry_name = Module.concat(name, "Registry")
    supervisor_name = Module.concat(name, "Supervisor")
    {registry_name, supervisor_name}
  end
end
