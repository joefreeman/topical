defmodule Topical.RegistryTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Topical.Registry

  setup do
    registry_name = :"test_registry_#{System.unique_integer([:positive])}"

    start_supervised!(%{
      id: registry_name,
      start:
        {Registry, :start_link,
         [
           [
             name: registry_name,
             topics: [
               Topical.Test.CounterTopic,
               Topical.Test.AuthorizedTopic,
               Topical.Test.CallbackTopic,
               Topical.Test.FailingTopic,
               Topical.Test.ListTopic,
               Topical.Test.MergeTopic,
               Topical.Test.LeaderboardTopic,
               Topical.Test.DocumentTopic
             ]
           ]
         ]}
    })

    {:ok, registry: registry_name}
  end

  describe "lookup_topic/2" do
    test "returns {:error, :not_running} for non-existent topic", %{registry: registry} do
      assert {:error, :not_running} = Registry.lookup_topic(registry, ["counters", "nonexistent"])
    end

    test "returns {:ok, pid} for running topic", %{registry: registry} do
      {:ok, pid} = Registry.get_topic(registry, ["counters", "1"], nil)
      assert {:ok, ^pid} = Registry.lookup_topic(registry, ["counters", "1"])
    end
  end

  describe "get_topic/3" do
    test "starts topic on first access", %{registry: registry} do
      {:ok, pid} = Registry.get_topic(registry, ["counters", "1"], nil)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "returns same pid for same route", %{registry: registry} do
      {:ok, pid1} = Registry.get_topic(registry, ["counters", "1"], nil)
      {:ok, pid2} = Registry.get_topic(registry, ["counters", "1"], nil)
      assert pid1 == pid2
    end

    test "returns different pids for different routes", %{registry: registry} do
      {:ok, pid1} = Registry.get_topic(registry, ["counters", "1"], nil)
      {:ok, pid2} = Registry.get_topic(registry, ["counters", "2"], nil)
      assert pid1 != pid2
    end

    test "returns {:error, :not_found} for unknown route", %{registry: registry} do
      assert {:error, :not_found} = Registry.get_topic(registry, ["unknown", "route"], nil)
    end

    test "returns {:error, :not_found} for partial route match", %{registry: registry} do
      assert {:error, :not_found} = Registry.get_topic(registry, ["counters"], nil)
    end

    test "returns {:error, :not_found} for too long route", %{registry: registry} do
      assert {:error, :not_found} = Registry.get_topic(registry, ["counters", "1", "extra"], nil)
    end

    test "passes params to topic init", %{registry: registry} do
      {:ok, pid} = Registry.get_topic(registry, ["counters", "my-id"], nil)
      state = :sys.get_state(pid)
      assert state.topic.state.id == "my-id"
    end
  end

  describe "route matching" do
    test "matches static route parts", %{registry: registry} do
      {:ok, _pid} = Registry.get_topic(registry, ["counters", "test"], nil)
    end

    test "captures placeholder values", %{registry: registry} do
      {:ok, pid} = Registry.get_topic(registry, ["private", "user123"], %{user_id: "user123"})
      state = :sys.get_state(pid)
      assert state.topic.value.owner == "user123"
    end

    test "accepts string route format", %{registry: registry} do
      {:ok, pid} = Registry.get_topic(registry, "counters/1", nil)
      assert is_pid(pid)
    end

    test "accepts URI-encoded route parts", %{registry: registry} do
      {:ok, pid} = Registry.get_topic(registry, "counters/hello%20world", nil)
      state = :sys.get_state(pid)
      assert state.topic.state.id == "hello world"
    end
  end

  describe "authorization" do
    test "allows access when authorized", %{registry: registry} do
      context = %{user_id: "owner1"}
      assert {:ok, _pid} = Registry.get_topic(registry, ["private", "owner1"], context)
    end

    test "denies access when unauthorized", %{registry: registry} do
      context = %{user_id: "other"}
      assert {:error, :forbidden} = Registry.get_topic(registry, ["private", "owner1"], context)
    end

    test "denies access when context is nil for authorized topic", %{registry: registry} do
      assert {:error, :unauthorized} = Registry.get_topic(registry, ["private", "owner1"], nil)
    end

    test "runs authorize before starting topic", %{registry: registry} do
      context = %{user_id: "wrong"}
      assert {:error, :forbidden} = Registry.get_topic(registry, ["private", "owner1"], context)

      # Topic should not have been started
      assert {:error, :not_running} = Registry.lookup_topic(registry, ["private", "owner1"])
    end

    test "authorize is called on every get_topic call", %{registry: registry} do
      # First call should succeed and start topic
      context1 = %{user_id: "owner1"}
      {:ok, pid} = Registry.get_topic(registry, ["private", "owner1"], context1)
      assert Process.alive?(pid)

      # Second call with wrong context should still fail
      context2 = %{user_id: "wrong"}
      assert {:error, :forbidden} = Registry.get_topic(registry, ["private", "owner1"], context2)
    end
  end

  describe "topic initialization errors" do
    test "returns error when topic init fails", %{registry: registry} do
      # Capture the expected SASL error log from GenServer init failure
      capture_log(fn ->
        assert {:error, :init_failed} =
                 Registry.get_topic(registry, ["failing", "init_error"], nil)
      end)
    end
  end

  describe "multiple registries" do
    test "topics are isolated between registries" do
      registry1 = :"registry1_#{System.unique_integer([:positive])}"
      registry2 = :"registry2_#{System.unique_integer([:positive])}"

      start_supervised!(
        %{
          id: registry1,
          start: {Registry, :start_link, [[name: registry1, topics: [Topical.Test.CounterTopic]]]}
        },
        id: :reg1
      )

      start_supervised!(
        %{
          id: registry2,
          start: {Registry, :start_link, [[name: registry2, topics: [Topical.Test.CounterTopic]]]}
        },
        id: :reg2
      )

      {:ok, pid1} = Registry.get_topic(registry1, ["counters", "1"], nil)
      {:ok, pid2} = Registry.get_topic(registry2, ["counters", "1"], nil)

      assert pid1 != pid2
    end
  end
end
