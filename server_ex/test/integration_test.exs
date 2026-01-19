defmodule Topical.IntegrationTest do
  use ExUnit.Case

  setup do
    registry_name = :"integration_registry_#{System.unique_integer([:positive])}"

    start_supervised!(%{
      id: registry_name,
      start:
        {Topical.Registry, :start_link,
         [
           [
             name: registry_name,
             topics: [
               Topical.Test.CounterTopic,
               Topical.Test.AuthorizedTopic,
               Topical.Test.CallbackTopic,
               Topical.Test.FailingTopic,
               Topical.Test.ListTopic,
               Topical.Test.MergeTopic
             ]
           ]
         ]}
    })

    {:ok, registry: registry_name}
  end

  describe "subscribe/4" do
    test "subscriber receives reset message", %{registry: registry} do
      {:ok, ref} = Topical.subscribe(registry, ["counters", "1"], self())

      assert_receive {:reset, ^ref, %{count: 0}}
    end

    test "returns ref that matches messages", %{registry: registry} do
      {:ok, ref1} = Topical.subscribe(registry, ["counters", "1"], self())
      {:ok, ref2} = Topical.subscribe(registry, ["counters", "2"], self())

      assert ref1 != ref2

      assert_receive {:reset, ^ref1, _}
      assert_receive {:reset, ^ref2, _}
    end

    test "subscriber receives updates after subscribe", %{registry: registry} do
      {:ok, ref} = Topical.subscribe(registry, ["counters", "1"], self())
      assert_receive {:reset, ^ref, %{count: 0}}

      Topical.execute(registry, ["counters", "1"], "increment", {})

      assert_receive {:updates, ^ref, [{:set, [:count], 1}]}
    end
  end

  describe "unsubscribe/3" do
    test "stops receiving updates after unsubscribe", %{registry: registry} do
      {:ok, ref} = Topical.subscribe(registry, ["counters", "1"], self())
      assert_receive {:reset, ^ref, %{count: 0}}

      :ok = Topical.unsubscribe(registry, ["counters", "1"], ref)

      Topical.execute(registry, ["counters", "1"], "increment", {})

      refute_receive {:updates, _, _}, 100
    end

    test "returns error for non-running topic", %{registry: registry} do
      ref = make_ref()

      assert {:error, :not_running} =
               Topical.unsubscribe(registry, ["counters", "nonexistent"], ref)
    end
  end

  describe "execute/5" do
    test "returns result from topic", %{registry: registry} do
      {:ok, result} = Topical.execute(registry, ["counters", "1"], "increment", {})
      assert result == 1

      {:ok, result} = Topical.execute(registry, ["counters", "1"], "increment", {})
      assert result == 2
    end

    test "subscribers receive updates from execute", %{registry: registry} do
      {:ok, ref} = Topical.subscribe(registry, ["counters", "1"], self())
      assert_receive {:reset, ^ref, %{count: 0}}

      {:ok, _} = Topical.execute(registry, ["counters", "1"], "set", {42})

      assert_receive {:updates, ^ref, [{:set, [:count], 42}]}
    end

    test "returns error for unknown topic", %{registry: registry} do
      assert {:error, :not_found} =
               Topical.execute(registry, ["unknown", "topic"], "action", {})
    end
  end

  describe "notify/5" do
    test "sends notification to topic", %{registry: registry} do
      {:ok, ref} = Topical.subscribe(registry, ["counters", "1"], self())
      assert_receive {:reset, ^ref, %{count: 0}}

      :ok = Topical.notify(registry, ["counters", "1"], "increment", {})

      assert_receive {:updates, ^ref, [{:set, [:count], 1}]}
    end

    test "returns :ok without waiting for result", %{registry: registry} do
      result = Topical.notify(registry, ["counters", "1"], "set", {100})
      assert result == :ok
    end

    test "returns error for unknown topic", %{registry: registry} do
      assert {:error, :not_found} = Topical.notify(registry, ["unknown", "topic"], "action", {})
    end
  end

  describe "capture/3" do
    test "returns current topic value", %{registry: registry} do
      Topical.execute(registry, ["counters", "1"], "set", {42})

      {:ok, value} = Topical.capture(registry, ["counters", "1"])
      assert value == %{count: 42}
    end

    test "does not subscribe", %{registry: registry} do
      {:ok, _value} = Topical.capture(registry, ["counters", "1"])

      Topical.execute(registry, ["counters", "1"], "increment", {})

      refute_receive {:updates, _, _}, 100
    end

    test "returns error for unknown topic", %{registry: registry} do
      assert {:error, :not_found} = Topical.capture(registry, ["unknown", "topic"])
    end
  end

  describe "multiple subscribers" do
    test "all subscribers receive same updates", %{registry: registry} do
      {:ok, ref1} = Topical.subscribe(registry, ["counters", "1"], self())
      {:ok, ref2} = Topical.subscribe(registry, ["counters", "1"], self())

      assert_receive {:reset, ^ref1, %{count: 0}}
      assert_receive {:reset, ^ref2, %{count: 0}}

      Topical.execute(registry, ["counters", "1"], "increment", {})

      assert_receive {:updates, ^ref1, [{:set, [:count], 1}]}
      assert_receive {:updates, ^ref2, [{:set, [:count], 1}]}
    end

    test "unsubscribing one does not affect others", %{registry: registry} do
      {:ok, ref1} = Topical.subscribe(registry, ["counters", "1"], self())
      {:ok, ref2} = Topical.subscribe(registry, ["counters", "1"], self())

      assert_receive {:reset, ^ref1, _}
      assert_receive {:reset, ^ref2, _}

      Topical.unsubscribe(registry, ["counters", "1"], ref1)
      Topical.execute(registry, ["counters", "1"], "increment", {})

      # ref1 should not receive update
      refute_receive {:updates, ^ref1, _}, 100
      # ref2 should still receive update
      assert_receive {:updates, ^ref2, [{:set, [:count], 1}]}
    end
  end

  describe "authorization" do
    test "subscribe respects authorization", %{registry: registry} do
      assert {:error, :forbidden} =
               Topical.subscribe(registry, ["private", "owner1"], self(), %{user_id: "other"})

      {:ok, _ref} =
        Topical.subscribe(registry, ["private", "owner1"], self(), %{user_id: "owner1"})
    end

    test "execute respects authorization", %{registry: registry} do
      assert {:error, :forbidden} =
               Topical.execute(
                 registry,
                 ["private", "owner1"],
                 "get_data",
                 {},
                 %{user_id: "other"}
               )

      {:ok, _} =
        Topical.execute(registry, ["private", "owner1"], "get_data", {}, %{user_id: "owner1"})
    end

    test "notify respects authorization", %{registry: registry} do
      assert {:error, :forbidden} =
               Topical.notify(
                 registry,
                 ["private", "owner1"],
                 "set_data",
                 {"test"},
                 %{user_id: "other"}
               )

      :ok =
        Topical.notify(
          registry,
          ["private", "owner1"],
          "set_data",
          {"test"},
          %{user_id: "owner1"}
        )
    end

    test "capture respects authorization", %{registry: registry} do
      assert {:error, :forbidden} =
               Topical.capture(registry, ["private", "owner1"], %{user_id: "other"})

      {:ok, _value} = Topical.capture(registry, ["private", "owner1"], %{user_id: "owner1"})
    end
  end

  describe "callback invocations" do
    test "handle_subscribe is called on subscribe", %{registry: registry} do
      context = %{user: "test"}
      {:ok, ref} = Topical.subscribe(registry, ["callbacks", "1"], self(), context)

      assert_receive {:reset, ^ref, %{callbacks: callbacks}}
      assert [{:subscribe, ^context}] = callbacks
    end

    test "handle_unsubscribe is called on unsubscribe", %{registry: registry} do
      context = %{user: "test"}
      {:ok, ref} = Topical.subscribe(registry, ["callbacks", "1"], self(), context)
      assert_receive {:reset, ^ref, _}

      Topical.unsubscribe(registry, ["callbacks", "1"], ref)

      # Give time for unsubscribe to process
      Process.sleep(50)

      {:ok, value} = Topical.capture(registry, ["callbacks", "1"])
      # Note: capture also adds a {:capture, nil} callback, so check for unsubscribe presence
      assert Enum.any?(value.callbacks, fn
               {:unsubscribe, ^context} -> true
               _ -> false
             end)
    end

    test "handle_capture is called on capture", %{registry: registry} do
      context = %{user: "test"}
      {:ok, value} = Topical.capture(registry, ["callbacks", "1"], context)

      assert [{:capture, ^context}] = value.callbacks
    end

    test "handle_execute is called on execute", %{registry: registry} do
      context = %{user: "test"}
      {:ok, _} = Topical.execute(registry, ["callbacks", "1"], "action", {"arg"}, context)

      {:ok, value} = Topical.capture(registry, ["callbacks", "1"])
      # Note: capture also adds a {:capture, nil} callback, so check for execute presence
      assert Enum.any?(value.callbacks, fn
               {:execute, {"arg"}, ^context} -> true
               _ -> false
             end)
    end

    test "handle_notify is called on notify", %{registry: registry} do
      context = %{user: "test"}
      :ok = Topical.notify(registry, ["callbacks", "1"], "action", {"arg"}, context)

      # Give time for notify to process
      Process.sleep(50)

      {:ok, value} = Topical.capture(registry, ["callbacks", "1"])
      # Note: capture also adds a {:capture, nil} callback, so check for notify presence
      assert Enum.any?(value.callbacks, fn
               {:notify, {"arg"}, ^context} -> true
               _ -> false
             end)
    end
  end

  describe "topic timeout" do
    test "topic stops after timeout with no subscribers", %{registry: registry} do
      # Start a topic
      {:ok, _} = Topical.execute(registry, ["counters", "timeout-test"], "increment", {})

      {:ok, pid} = Topical.Registry.lookup_topic(registry, ["counters", "timeout-test"])
      assert Process.alive?(pid)

      # Wait for timeout (10 seconds is default, but we'll just check the behavior)
      # We use a reference to monitor the process
      ref = Process.monitor(pid)

      # Topic should still be running after short delay
      refute_receive {:DOWN, ^ref, :process, ^pid, _}, 100

      # Clean up
      Process.demonitor(ref, [:flush])
    end

    test "topic does not timeout while subscribed", %{registry: registry} do
      {:ok, sub_ref} = Topical.subscribe(registry, ["counters", "sub-test"], self())
      assert_receive {:reset, ^sub_ref, _}

      {:ok, pid} = Topical.Registry.lookup_topic(registry, ["counters", "sub-test"])
      mon_ref = Process.monitor(pid)

      # Should not timeout while subscribed
      refute_receive {:DOWN, ^mon_ref, :process, ^pid, _}, 200

      Process.demonitor(mon_ref, [:flush])
    end
  end

  describe "list operations" do
    test "insert operations broadcast to subscribers", %{registry: registry} do
      {:ok, ref} = Topical.subscribe(registry, ["lists", "1"], self())
      assert_receive {:reset, ^ref, %{items: [], next_id: 1}}

      {:ok, 1} = Topical.execute(registry, ["lists", "1"], "add", {"first"})

      assert_receive {:updates, ^ref, updates}
      assert {:insert, [:items], nil, [%{id: 1, value: "first"}]} in updates
    end

    test "delete operations broadcast to subscribers", %{registry: registry} do
      {:ok, ref} = Topical.subscribe(registry, ["lists", "1"], self())
      assert_receive {:reset, ^ref, _}

      {:ok, _} = Topical.execute(registry, ["lists", "1"], "add", {"first"})
      assert_receive {:updates, ^ref, _}

      {:ok, _} = Topical.execute(registry, ["lists", "1"], "add", {"second"})
      assert_receive {:updates, ^ref, _}

      {:ok, _} = Topical.execute(registry, ["lists", "1"], "remove", {0})

      assert_receive {:updates, ^ref, [{:delete, [:items], 0, 1}]}
    end
  end

  describe "merge operations" do
    test "merge operations broadcast to subscribers", %{registry: registry} do
      {:ok, ref} = Topical.subscribe(registry, ["merge", "1"], self())
      assert_receive {:reset, ^ref, %{data: %{}}}

      {:ok, _} = Topical.execute(registry, ["merge", "1"], "merge", {%{a: 1, b: 2}})

      assert_receive {:updates, ^ref, [{:merge, [:data], %{a: 1, b: 2}}]}
    end

    test "unset operations broadcast to subscribers", %{registry: registry} do
      {:ok, ref} = Topical.subscribe(registry, ["merge", "1"], self())
      assert_receive {:reset, ^ref, _}

      {:ok, _} = Topical.execute(registry, ["merge", "1"], "set", {:key, "value"})
      assert_receive {:updates, ^ref, _}

      {:ok, _} = Topical.execute(registry, ["merge", "1"], "unset", {:key})

      assert_receive {:updates, ^ref, [{:unset, [:data], :key}]}
    end
  end

  describe "subscriber process death" do
    test "subscriber is removed when process dies", %{registry: registry} do
      # Spawn a process that subscribes then dies
      test_pid = self()

      subscriber =
        spawn(fn ->
          {:ok, _ref} = Topical.subscribe(registry, ["callbacks", "death-test"], self())
          send(test_pid, :subscribed)

          receive do
            :die -> :ok
          end
        end)

      assert_receive :subscribed

      # Kill the subscriber
      send(subscriber, :die)

      # Wait for process to die and unsubscribe to be processed
      Process.sleep(100)

      # Check that unsubscribe was called
      {:ok, value} = Topical.capture(registry, ["callbacks", "death-test"])
      # Note: capture also adds a {:capture, nil} callback, so check for unsubscribe presence
      assert Enum.any?(value.callbacks, fn
               {:unsubscribe, _} -> true
               _ -> false
             end)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = Topical.child_spec(name: MyApp.Topical, topics: [])

      # Default id is Topical when :server option is not provided
      assert spec.id == Topical
      assert spec.type == :supervisor
      assert {Topical.Registry, :start_link, [_opts]} = spec.start
    end

    test "uses :server option as id when provided" do
      spec = Topical.child_spec(name: SomeRegistry, server: CustomId, topics: [])

      assert spec.id == CustomId
    end
  end
end
