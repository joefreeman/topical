defmodule Topical.Adapters.Cowboy.RestHandler do
  @moduledoc """
  A REST-ish handler adapter for a Cowboy web server.

  ## Options

   - `registry` - The name of the Topical registry. Required.
   - `init` - A function called before starting/capturing the topic, passed the request. The
     function must return `{:ok, context}` for the connection to be accepted. This `context` is
     then passed to topics.

  ## Example

      :cowboy_router.compile([
        {:_,
         [
           # ...
           {"/topics/[...]", RestHandler, registry: MyApp.Topical}
         ]}
      ])
  """

  @doc false
  def init(req, opts) do
    registry = Keyword.fetch!(opts, :registry)
    init = Keyword.get(opts, :init)
    path_info = :cowboy_req.path_info(req)
    topic = Enum.join(path_info, "/")

    result = if init, do: init.(req), else: {:ok, nil}

    case result do
      {:ok, context} ->
        case Topical.capture(registry, topic, context) do
          {:ok, value} ->
            json = Jason.encode!(value)
            req = :cowboy_req.reply(200, %{"content-type" => "application/json"}, json, req)
            {:ok, req, opts}
        end
    end
  end
end
