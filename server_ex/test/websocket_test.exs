for adapter <- [:cowboy, :bandit] do
  module_name = Module.concat(Topical.WebSocketTest, adapter |> Atom.to_string() |> Macro.camelize())

  defmodule module_name do
    use ExUnit.Case, async: false

    import Topical.Test.WebSocketTestHelper

    @adapter adapter

    setup do
      %{port: port} = start_server(@adapter)
      ws = ws_connect(port)
      on_exit(fn -> ws_close(ws) end)
      {:ok, ws: ws, port: port}
    end

    describe "subscribe & reset" do
      test "subscribe receives initial value", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "sub-reset-1"]))
        msg = ws_receive(ws)

        # [2, channel_id, value] = topic_reset
        assert [2, "ch1", %{"count" => 0}] = msg
      end

      test "subscribe to unknown route returns error", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["nonexistent", "route"]))
        msg = ws_receive(ws)

        # [0, channel_id, error] = error
        assert [0, "ch1", "not_found"] = msg
      end

      test "multiple subscribes to different topics get independent resets", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "multi-a"]))
        ws_send(ws, subscribe_msg("ch2", ["counters", "multi-b"]))

        msgs = ws_receive_all(ws, 2)
        channel_ids = Enum.map(msgs, fn [_, ch_id | _] -> ch_id end)

        assert "ch1" in channel_ids
        assert "ch2" in channel_ids

        Enum.each(msgs, fn msg ->
          assert [2, _, %{"count" => 0}] = msg
        end)
      end
    end

    describe "execute & result" do
      test "execute returns result value", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "exec-1"]))
        _reset = ws_receive(ws)

        ws_send(ws, execute_msg("req1", ["counters", "exec-1"], "increment", []))
        msg = ws_receive(ws)

        # [1, channel_id, result] = result
        assert [1, "req1", 1] = msg
      end

      test "execute broadcasts update to subscriber", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "exec-2"]))
        _reset = ws_receive(ws)

        ws_send(ws, execute_msg("req1", ["counters", "exec-2"], "increment", []))

        # We should get both a result and an update
        msgs = ws_receive_all(ws, 2)
        types = Enum.map(msgs, fn [type | _] -> type end)

        assert 1 in types  # result
        assert 3 in types  # topic_updates

        update_msg = Enum.find(msgs, fn [type | _] -> type == 3 end)
        assert [3, "ch1", [[0, ["count"], 1]]] = update_msg
      end

      test "execute on unknown topic returns error", %{ws: ws} do
        ws_send(ws, execute_msg("req1", ["nonexistent", "topic"], "action", []))
        msg = ws_receive(ws)

        assert [0, "req1", "not_found"] = msg
      end

      test "execute with arguments works", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "exec-args"]))
        _reset = ws_receive(ws)

        ws_send(ws, execute_msg("req1", ["counters", "exec-args"], "set", [42]))

        msgs = ws_receive_all(ws, 2)
        result_msg = Enum.find(msgs, fn [type | _] -> type == 1 end)
        assert [1, "req1", 42] = result_msg
      end
    end

    describe "notify & updates" do
      test "notify triggers update to subscriber", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "notify-1"]))
        _reset = ws_receive(ws)

        ws_send(ws, notify_msg(["counters", "notify-1"], "increment", []))

        msg = ws_receive(ws)
        assert [3, "ch1", [[0, ["count"], 1]]] = msg
      end

      test "notify does not produce a result response", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "notify-2"]))
        _reset = ws_receive(ws)

        ws_send(ws, notify_msg(["counters", "notify-2"], "increment", []))

        msg = ws_receive(ws)
        # Should only get update (type 3), not result (type 1)
        assert [3, "ch1", _updates] = msg
        ws_refute_receive(ws)
      end

      test "notify with arguments works", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "notify-args"]))
        _reset = ws_receive(ws)

        ws_send(ws, notify_msg(["counters", "notify-args"], "set", [99]))

        msg = ws_receive(ws)
        assert [3, "ch1", [[0, ["count"], 99]]] = msg
      end
    end

    describe "unsubscribe" do
      test "unsubscribe stops updates", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "unsub-1"]))
        _reset = ws_receive(ws)

        ws_send(ws, unsubscribe_msg("ch1"))
        # Give time for unsubscribe to process
        Process.sleep(50)

        ws_send(ws, notify_msg(["counters", "unsub-1"], "increment", []))
        ws_refute_receive(ws)
      end

      test "unsubscribe unknown channel is a no-op", %{ws: ws} do
        ws_send(ws, unsubscribe_msg("nonexistent"))
        # Should not crash the connection
        ws_send(ws, subscribe_msg("ch1", ["counters", "unsub-noop"]))
        msg = ws_receive(ws)
        assert [2, "ch1", %{"count" => 0}] = msg
      end

      test "can resubscribe after unsubscribe", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "unsub-resub"]))
        _reset = ws_receive(ws)

        # Increment before unsubscribe
        ws_send(ws, execute_msg("req1", ["counters", "unsub-resub"], "increment", []))
        _msgs = ws_receive_all(ws, 2)

        ws_send(ws, unsubscribe_msg("ch1"))
        Process.sleep(50)

        # Resubscribe on new channel
        ws_send(ws, subscribe_msg("ch2", ["counters", "unsub-resub"]))
        msg = ws_receive(ws)

        # Should get reset with current value (count=1)
        assert [2, "ch2", %{"count" => 1}] = msg
      end
    end

    describe "multiple connections" do
      test "two connections both receive updates for shared topic", %{ws: ws, port: port} do
        ws2 = ws_connect(port)

        ws_send(ws, subscribe_msg("ch1", ["counters", "multi-conn-1"]))
        _reset1 = ws_receive(ws)

        ws_send(ws2, subscribe_msg("ch1", ["counters", "multi-conn-1"]))
        _reset2 = ws_receive(ws2)

        ws_send(ws, execute_msg("req1", ["counters", "multi-conn-1"], "increment", []))

        # ws gets both result and update
        msgs1 = ws_receive_all(ws, 2)
        assert Enum.any?(msgs1, fn [type | _] -> type == 3 end)

        # ws2 gets update only
        msg2 = ws_receive(ws2)
        assert [3, "ch1", [[0, ["count"], 1]]] = msg2

        ws_close(ws2)
      end

      test "one unsubscribing doesn't affect the other", %{ws: ws, port: port} do
        ws2 = ws_connect(port)

        ws_send(ws, subscribe_msg("ch1", ["counters", "multi-conn-2"]))
        _reset1 = ws_receive(ws)

        ws_send(ws2, subscribe_msg("ch1", ["counters", "multi-conn-2"]))
        _reset2 = ws_receive(ws2)

        ws_send(ws, unsubscribe_msg("ch1"))
        Process.sleep(50)

        ws_send(ws2, execute_msg("req1", ["counters", "multi-conn-2"], "increment", []))

        # ws should NOT get updates
        ws_refute_receive(ws)

        # ws2 gets result + update
        msgs = ws_receive_all(ws2, 2)
        assert Enum.any?(msgs, fn [type | _] -> type == 1 end)
        assert Enum.any?(msgs, fn [type | _] -> type == 3 end)

        ws_close(ws2)
      end
    end

    describe "authorization" do
      test "subscribe without required context returns error", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["private", "user1"]))
        msg = ws_receive(ws)

        assert [0, "ch1", "unauthorized"] = msg
      end

      test "subscribe with correct context succeeds", %{port: _port} do
        %{port: port} = start_server(@adapter, init: fn _req -> {:ok, %{user_id: "user1"}} end)
        ws = ws_connect(port)

        ws_send(ws, subscribe_msg("ch1", ["private", "user1"]))
        msg = ws_receive(ws)

        assert [2, "ch1", %{"owner" => "user1", "data" => nil}] = msg
        ws_close(ws)
      end
    end

    describe "params" do
      test "subscribe with explicit params", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["leaderboards", "chess"], %{"region" => "eu"}))
        msg = ws_receive(ws)

        assert [2, "ch1", %{"game_id" => "chess", "region" => "eu", "entries" => []}] = msg
      end

      test "subscribe with default params", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["leaderboards", "chess"]))
        msg = ws_receive(ws)

        assert [2, "ch1", %{"game_id" => "chess", "region" => "global", "entries" => []}] = msg
      end
    end

    describe "aliases" do
      test "subscribing to same topic twice returns alias response", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "alias-1"]))
        _reset = ws_receive(ws)

        ws_send(ws, subscribe_msg("ch2", ["counters", "alias-1"]))
        msg = ws_receive(ws)

        # [4, channel_id, existing_channel_id] = topic_alias
        assert [4, "ch2", "ch1"] = msg
      end

      test "after unsubscribe + resubscribe, no alias (fresh subscription)", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["counters", "alias-2"]))
        _reset = ws_receive(ws)

        ws_send(ws, unsubscribe_msg("ch1"))
        Process.sleep(50)

        ws_send(ws, subscribe_msg("ch2", ["counters", "alias-2"]))
        msg = ws_receive(ws)

        # Should be a reset, not an alias
        assert [2, "ch2", %{"count" => 0}] = msg
      end
    end

    describe "complex updates" do
      test "list insert operations", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["lists", "complex-1"]))
        _reset = ws_receive(ws)

        ws_send(ws, execute_msg("req1", ["lists", "complex-1"], "add", ["first"]))
        msgs = ws_receive_all(ws, 2)

        update_msg = Enum.find(msgs, fn [type | _] -> type == 3 end)
        [3, "ch1", updates] = update_msg

        # Should contain an insert operation (opcode 2)
        assert Enum.any?(updates, fn [opcode | _] -> opcode == 2 end)
      end

      test "merge operations", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["merge", "complex-1"]))
        _reset = ws_receive(ws)

        ws_send(ws, execute_msg("req1", ["merge", "complex-1"], "merge", [%{"a" => 1, "b" => 2}]))
        msgs = ws_receive_all(ws, 2)

        update_msg = Enum.find(msgs, fn [type | _] -> type == 3 end)
        [3, "ch1", updates] = update_msg

        # Should contain a merge operation (opcode 4)
        assert Enum.any?(updates, fn [opcode | _] -> opcode == 4 end)
      end

      test "unset operations", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["merge", "complex-2"]))
        _reset = ws_receive(ws)

        # First set a key
        ws_send(ws, execute_msg("req1", ["merge", "complex-2"], "set", ["mykey", "myvalue"]))
        _msgs = ws_receive_all(ws, 2)

        # Now unset it
        ws_send(ws, execute_msg("req2", ["merge", "complex-2"], "unset", ["mykey"]))
        msgs = ws_receive_all(ws, 2)

        update_msg = Enum.find(msgs, fn [type | _] -> type == 3 end)
        [3, "ch1", updates] = update_msg

        # Should contain an unset operation (opcode 1)
        assert Enum.any?(updates, fn [opcode | _] -> opcode == 1 end)
      end
    end

    describe "error handling" do
      test "topic with init error returns error", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["failing", "init_error"]))
        msg = ws_receive(ws)

        assert [0, "ch1", _error] = msg
      end

      test "connection survives after error response", %{ws: ws} do
        ws_send(ws, subscribe_msg("ch1", ["nonexistent", "route"]))
        msg = ws_receive(ws)
        assert [0, "ch1", "not_found"] = msg

        # Connection should still work
        ws_send(ws, subscribe_msg("ch2", ["counters", "survive-1"]))
        msg = ws_receive(ws)
        assert [2, "ch2", %{"count" => 0}] = msg
      end
    end
  end
end
