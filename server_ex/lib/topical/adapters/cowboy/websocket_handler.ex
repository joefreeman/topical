defmodule Topical.Adapters.Cowboy.WebsocketHandler do
  @moduledoc """
  A WebSocket handler adapter for a Cowboy web server.

  ## Options

   - `registry` - The name of the Topical registry. Required.
   - `init` - A function called before upgrading the connection, which is passed the request. The
     function must return `{:ok, context}` for the connection to be accepted. This `context` is then
     passed to topics.

  ## Example

      :cowboy_router.compile([
        {:_,
         [
           # ...
           {"/socket", WebsocketHandler, registry: MyApp.Topical}
         ]}
      ])
  """

  alias Topical.Adapters.Base.WebSocket, as: Base

  @doc false
  def init(req, opts) do
    case Base.init(opts, req) do
      {:ok, state} ->
        {:cowboy_websocket, req, state}
    end
  end

  @doc false
  def websocket_handle({:text, text}, state) do
    case Base.handle_text(text, state) do
      {:ok, messages, state} ->
        {Enum.map(messages, &{:text, &1}), state}
    end
  end

  @doc false
  def websocket_handle(_data, state) do
    {[], state}
  end

  @doc false
  def websocket_info(info, state) do
    case Base.handle_info(info, state) do
      {:ok, messages, state} ->
        {Enum.map(messages, &{:text, &1}), state}
    end
  end
end
