defmodule Topical.Topic do
  alias Topical.Topic.Utils

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      alias Topical.Topic

      def route() do
        unquote(Keyword.fetch!(opts, :route))
      end

      def handle_notify(_action, _args, _topic) do
        raise "no handle_notify/3 implemented"
      end

      def handle_execute(_action, _args, _topic) do
        raise "no handle_execute/3 implemented"
      end

      def handle_info(_msg, topic) do
        # TODO: log warning?
        {:ok, topic}
      end

      def terminate(_reason, _topic) do
        :ok
      end

      defoverridable handle_notify: 3, handle_execute: 3, handle_info: 2, terminate: 2
    end
  end

  defstruct [:state, :value, :updates]

  def new(value, state \\ nil) do
    %__MODULE__{value: value, state: state, updates: []}
  end

  def update(topic, path, value) do
    topic_value = Utils.apply_update({path, value}, topic.value)

    topic
    |> Map.update!(:updates, &[{path, value} | &1])
    |> Map.put(:value, topic_value)
  end
end
