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

  # Resolves a route and normalizes request params.
  # Returns {:ok, module, all_params, topic_key} or {:error, reason}
  defp resolve_topic(route, routes, request_params) do
    case resolve_route(route, routes) do
      {module, route_params} ->
        case normalize_params(request_params, module.params()) do
          {:ok, normalized_params} ->
            topic_key = {route, normalized_params}
            all_params = Keyword.merge(route_params, normalized_params)
            {:ok, module, all_params, topic_key}

          {:error, reason} ->
            {:error, reason}
        end

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Looks up an existing topic without starting it.

  Returns `{:ok, pid}` if the topic is running, or `{:error, :not_running}` if not.
  """
  def lookup_topic(name, route, request_params \\ %{}) do
    {registry_name, _supervisor_name} = resolve_names(name)
    {:ok, routes} = Registry.meta(registry_name, :routes)

    with {:ok, _module, _all_params, topic_key} <- resolve_topic(route, routes, request_params) do
      case Registry.lookup(registry_name, topic_key) do
        [{pid, _}] -> {:ok, pid}
        [] -> {:error, :not_running}
      end
    end
  end

  @doc """
  Gets or starts a topic, after checking authorization.

  Returns `{:ok, pid}` if authorized and the topic is running (or was started),
  or `{:error, reason}` if authorization fails or the topic cannot be started.
  """
  def get_topic(name, route, context, request_params \\ %{}) do
    {registry_name, supervisor_name} = resolve_names(name)
    {:ok, routes} = Registry.meta(registry_name, :routes)

    with {:ok, module, all_params, topic_key} <- resolve_topic(route, routes, request_params) do
      case module.authorize(all_params, context) do
        :ok ->
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

        {:error, reason} ->
          {:error, reason}
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
