defmodule Topical.Test.CounterTopic do
  @moduledoc """
  Simple counter topic for basic testing.
  Route: ["counters", :id]
  Actions: "increment", "decrement", "set", "get"
  """
  use Topical.Topic, route: ["counters", :id]

  def init(params) do
    id = Keyword.fetch!(params, :id)
    value = %{count: 0}
    state = %{id: id}
    {:ok, Topic.new(value, state)}
  end

  def handle_execute("increment", {}, topic, _context) do
    new_count = topic.value.count + 1
    topic = Topic.set(topic, [:count], new_count)
    {:ok, new_count, topic}
  end

  def handle_execute("decrement", {}, topic, _context) do
    new_count = topic.value.count - 1
    topic = Topic.set(topic, [:count], new_count)
    {:ok, new_count, topic}
  end

  def handle_execute("set", {value}, topic, _context) do
    topic = Topic.set(topic, [:count], value)
    {:ok, value, topic}
  end

  def handle_execute("get", {}, topic, _context) do
    {:ok, topic.value.count, topic}
  end

  def handle_notify("increment", {}, topic, _context) do
    new_count = topic.value.count + 1
    topic = Topic.set(topic, [:count], new_count)
    {:ok, topic}
  end

  def handle_notify("set", {value}, topic, _context) do
    topic = Topic.set(topic, [:count], value)
    {:ok, topic}
  end
end

defmodule Topical.Test.AuthorizedTopic do
  @moduledoc """
  Topic with authorization logic.
  Route: ["private", :owner_id]
  Only allows access when context.user_id == owner_id
  """
  use Topical.Topic, route: ["private", :owner_id]

  def authorize(params, context) do
    owner_id = Keyword.fetch!(params, :owner_id)

    cond do
      context == nil ->
        {:error, :unauthorized}

      context[:user_id] == owner_id ->
        :ok

      true ->
        {:error, :forbidden}
    end
  end

  def init(params) do
    owner_id = Keyword.fetch!(params, :owner_id)
    value = %{owner: owner_id, data: nil}
    {:ok, Topic.new(value)}
  end

  def handle_execute("get_data", {}, topic, _context) do
    {:ok, topic.value.data, topic}
  end

  def handle_execute("set_data", {data}, topic, _context) do
    topic = Topic.set(topic, [:data], data)
    {:ok, :ok, topic}
  end

  def handle_notify("set_data", {data}, topic, _context) do
    topic = Topic.set(topic, [:data], data)
    {:ok, topic}
  end
end

defmodule Topical.Test.CallbackTopic do
  @moduledoc """
  Topic that tracks callback invocations.
  Used to verify callback order and arguments.
  Route: ["callbacks", :id]
  """
  use Topical.Topic, route: ["callbacks", :id]

  def init(params) do
    id = Keyword.fetch!(params, :id)
    value = %{callbacks: []}
    state = %{id: id}
    {:ok, Topic.new(value, state)}
  end

  def handle_subscribe(topic, context) do
    callbacks = topic.value.callbacks ++ [{:subscribe, context}]
    topic = Topic.set(topic, [:callbacks], callbacks)
    {:ok, topic}
  end

  def handle_unsubscribe(topic, context) do
    callbacks = topic.value.callbacks ++ [{:unsubscribe, context}]
    topic = Topic.set(topic, [:callbacks], callbacks)
    {:ok, topic}
  end

  def handle_capture(topic, context) do
    callbacks = topic.value.callbacks ++ [{:capture, context}]
    topic = Topic.set(topic, [:callbacks], callbacks)
    {:ok, topic}
  end

  def handle_execute("action", args, topic, context) do
    callbacks = topic.value.callbacks ++ [{:execute, args, context}]
    topic = Topic.set(topic, [:callbacks], callbacks)
    {:ok, :executed, topic}
  end

  def handle_notify("action", args, topic, context) do
    callbacks = topic.value.callbacks ++ [{:notify, args, context}]
    topic = Topic.set(topic, [:callbacks], callbacks)
    {:ok, topic}
  end

  def handle_info(msg, topic) do
    callbacks = topic.value.callbacks ++ [{:info, msg}]
    topic = Topic.set(topic, [:callbacks], callbacks)
    {:ok, topic}
  end
end

defmodule Topical.Test.FailingTopic do
  @moduledoc """
  Topic that fails in various ways for testing error handling.
  Route: ["failing", :id]
  """
  use Topical.Topic, route: ["failing", :id]

  def init(params) do
    id = Keyword.fetch!(params, :id)

    case id do
      "init_error" ->
        {:error, :init_failed}

      _ ->
        value = %{status: :ok}
        {:ok, Topic.new(value)}
    end
  end

  def handle_execute("raise", {}, _topic, _context) do
    raise "intentional error"
  end

  def handle_execute("throw", {}, _topic, _context) do
    throw(:intentional_throw)
  end

  def handle_execute("exit", {}, _topic, _context) do
    exit(:intentional_exit)
  end

  def handle_execute("ok", {}, topic, _context) do
    {:ok, :ok, topic}
  end
end

defmodule Topical.Test.ListTopic do
  @moduledoc """
  Topic for testing list operations (insert/delete).
  Route: ["lists", :id]
  """
  use Topical.Topic, route: ["lists", :id]

  def init(_params) do
    value = %{items: [], next_id: 1}
    {:ok, Topic.new(value)}
  end

  def handle_execute("add", {item}, topic, _context) do
    id = topic.value.next_id
    topic = Topic.insert(topic, [:items], %{id: id, value: item})
    topic = Topic.set(topic, [:next_id], id + 1)
    {:ok, id, topic}
  end

  def handle_execute("add_at", {index, item}, topic, _context) do
    id = topic.value.next_id
    topic = Topic.insert(topic, [:items], index, %{id: id, value: item})
    topic = Topic.set(topic, [:next_id], id + 1)
    {:ok, id, topic}
  end

  def handle_execute("remove", {index}, topic, _context) do
    topic = Topic.delete(topic, [:items], index)
    {:ok, :ok, topic}
  end

  def handle_execute("remove_many", {index, count}, topic, _context) do
    topic = Topic.delete(topic, [:items], index, count)
    {:ok, :ok, topic}
  end
end

defmodule Topical.Test.MergeTopic do
  @moduledoc """
  Topic for testing merge operations.
  Route: ["merge", :id]
  """
  use Topical.Topic, route: ["merge", :id]

  def init(_params) do
    value = %{data: %{}}
    {:ok, Topic.new(value)}
  end

  def handle_execute("merge", {new_data}, topic, _context) do
    topic = Topic.merge(topic, [:data], new_data)
    {:ok, topic.value.data, topic}
  end

  def handle_execute("set", {key, value}, topic, _context) do
    topic = Topic.set(topic, [:data, key], value)
    {:ok, :ok, topic}
  end

  def handle_execute("unset", {key}, topic, _context) do
    topic = Topic.unset(topic, [:data], key)
    {:ok, :ok, topic}
  end
end

defmodule Topical.Test.LeaderboardTopic do
  @moduledoc """
  Leaderboard topic for testing params feature.
  Route: ["leaderboards", :game_id]
  Params: [region: "global"]

  Different regions have separate leaderboards - global vs regional rankings.
  """
  use Topical.Topic, route: ["leaderboards", :game_id], params: [region: "global"]

  def init(params) do
    game_id = Keyword.fetch!(params, :game_id)
    region = Keyword.fetch!(params, :region)

    value = %{
      game_id: game_id,
      region: region,
      entries: []
    }

    {:ok, Topic.new(value)}
  end

  def handle_execute("get_info", {}, topic, _context) do
    result = %{
      game_id: topic.value.game_id,
      region: topic.value.region
    }

    {:ok, result, topic}
  end

  def handle_execute("add_score", {player, score}, topic, _context) do
    entry = %{player: player, score: score}
    topic = Topic.insert(topic, [:entries], entry)
    {:ok, :ok, topic}
  end

  def handle_notify("add_score", {player, score}, topic, _context) do
    entry = %{player: player, score: score}
    topic = Topic.insert(topic, [:entries], entry)
    {:ok, topic}
  end
end

defmodule Topical.Test.DocumentTopic do
  @moduledoc """
  Document topic for testing authorization with params.
  Route: ["documents", :doc_id]
  Params: [mode: "view"]

  Viewing a document is allowed for anyone, but editing requires :can_edit permission.
  """
  use Topical.Topic, route: ["documents", :doc_id], params: [mode: "view"]

  def authorize(params, context) do
    mode = Keyword.fetch!(params, :mode)

    cond do
      mode == "edit" and context[:can_edit] != true ->
        {:error, :edit_not_allowed}

      true ->
        :ok
    end
  end

  def init(params) do
    doc_id = Keyword.fetch!(params, :doc_id)
    mode = Keyword.fetch!(params, :mode)

    value = %{doc_id: doc_id, mode: mode, content: ""}
    {:ok, Topic.new(value)}
  end

  def handle_execute("get_mode", {}, topic, _context) do
    {:ok, topic.value.mode, topic}
  end

  def handle_execute("set_content", {content}, topic, _context) do
    topic = Topic.set(topic, [:content], content)
    {:ok, :ok, topic}
  end
end
