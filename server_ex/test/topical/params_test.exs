defmodule Topical.ParamsTest do
  use ExUnit.Case

  alias Topical.Registry

  describe "compile-time validation" do
    test "raises when param name conflicts with route placeholder" do
      assert_raise ArgumentError, ~r/param names conflict with route placeholders/, fn ->
        defmodule ConflictingTopic do
          # This should fail because :id is both in route and params
          use Topical.Topic, route: ["things", :id], params: [id: "default"]
        end
      end
    end
  end

  setup do
    registry_name = :"params_registry_#{System.unique_integer([:positive])}"

    start_supervised!(%{
      id: registry_name,
      start:
        {Registry, :start_link,
         [
           [
             name: registry_name,
             topics: [
               Topical.Test.CounterTopic,
               Topical.Test.LeaderboardTopic,
               Topical.Test.DocumentTopic
             ]
           ]
         ]}
    })

    {:ok, registry: registry_name}
  end

  describe "params normalization" do
    test "uses default values when params not provided", %{registry: registry} do
      {:ok, result} = Topical.execute(registry, ["leaderboards", "chess"], "get_info", {})

      assert result.game_id == "chess"
      assert result.region == "global"
    end

    test "uses provided params over defaults", %{registry: registry} do
      params = %{"region" => "eu"}
      {:ok, result} = Topical.execute(registry, ["leaderboards", "chess"], "get_info", {}, nil, params)

      assert result.game_id == "chess"
      assert result.region == "eu"
    end

    test "ignores unknown params", %{registry: registry} do
      params = %{"region" => "na", "unknown_param" => "ignored"}
      {:ok, result} = Topical.execute(registry, ["leaderboards", "chess"], "get_info", {}, nil, params)

      assert result.region == "na"
      # unknown_param is silently ignored
    end

    test "normalizes empty string to default", %{registry: registry} do
      params = %{"region" => ""}
      {:ok, result} = Topical.execute(registry, ["leaderboards", "chess"], "get_info", {}, nil, params)

      # Empty string should use default
      assert result.region == "global"
    end

    test "returns error for non-string param values", %{registry: registry} do
      # Integer value
      params = %{"region" => 123}

      assert {:error, {:invalid_param, :region}} =
               Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, params)

      # Boolean value
      params = %{"region" => true}

      assert {:error, {:invalid_param, :region}} =
               Topical.execute(registry, ["leaderboards", "chess"], "get_info", {}, nil, params)

      # List value
      params = %{"region" => ["eu", "na"]}

      assert {:error, {:invalid_param, :region}} =
               Topical.capture(registry, ["leaderboards", "chess"], nil, params)

      # Map value
      params = %{"region" => %{"code" => "eu"}}

      assert {:error, {:invalid_param, :region}} =
               Topical.notify(registry, ["leaderboards", "chess"], "add_score", {"alice", 100}, nil, params)
    end

    test "accepts both string and atom keys in params", %{registry: registry} do
      params = %{region: "asia"}
      {:ok, result} = Topical.execute(registry, ["leaderboards", "chess"], "get_info", {}, nil, params)

      assert result.region == "asia"
    end
  end

  describe "topic identity with params" do
    test "different regions create different leaderboard instances", %{registry: registry} do
      global_params = %{"region" => "global"}
      eu_params = %{"region" => "eu"}

      {:ok, ref_global} = Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, global_params)
      {:ok, ref_eu} = Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, eu_params)

      assert_receive {:reset, ^ref_global, value_global}
      assert_receive {:reset, ^ref_eu, value_eu}

      assert value_global.region == "global"
      assert value_eu.region == "eu"

      # Add score to global leaderboard
      Topical.execute(registry, ["leaderboards", "chess"], "add_score", {"alice", 100}, nil, global_params)

      # Only global subscribers should receive update
      assert_receive {:updates, ^ref_global, _}
      refute_receive {:updates, ^ref_eu, _}, 100
    end

    test "same region resolves to same leaderboard instance", %{registry: registry} do
      params = %{"region" => "na"}

      {:ok, ref1} = Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, params)
      {:ok, ref2} = Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, params)

      assert_receive {:reset, ^ref1, _}
      assert_receive {:reset, ^ref2, _}

      # Add score
      Topical.execute(registry, ["leaderboards", "chess"], "add_score", {"bob", 200}, nil, params)

      # Both refs should receive update (same leaderboard)
      assert_receive {:updates, ^ref1, _}
      assert_receive {:updates, ^ref2, _}
    end

    test "default params and explicit default params resolve to same topic", %{registry: registry} do
      # No params (uses default region: "global")
      {:ok, ref1} = Topical.subscribe(registry, ["leaderboards", "chess"], self())
      # Explicit default params
      {:ok, ref2} =
        Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, %{"region" => "global"})

      assert_receive {:reset, ^ref1, _}
      assert_receive {:reset, ^ref2, _}

      # Add score with no params (uses defaults)
      Topical.execute(registry, ["leaderboards", "chess"], "add_score", {"charlie", 150})

      # Both should receive update (same topic)
      assert_receive {:updates, ^ref1, _}
      assert_receive {:updates, ^ref2, _}
    end
  end

  describe "authorization with params" do
    test "view mode works without special permissions", %{registry: registry} do
      # View mode should work without context
      {:ok, _ref} = Topical.subscribe(registry, ["documents", "doc1"], self())
      assert_receive {:reset, _, %{mode: "view"}}
    end

    test "edit mode requires can_edit permission", %{registry: registry} do
      # Edit mode without can_edit context should fail
      params = %{"mode" => "edit"}

      assert {:error, :edit_not_allowed} =
               Topical.subscribe(registry, ["documents", "doc1"], self(), nil, params)
    end

    test "edit mode allowed with can_edit permission", %{registry: registry} do
      params = %{"mode" => "edit"}
      context = %{can_edit: true}

      {:ok, _ref} = Topical.subscribe(registry, ["documents", "doc1"], self(), context, params)
      assert_receive {:reset, _, %{mode: "edit"}}
    end
  end

  describe "unsubscribe with params" do
    test "unsubscribe uses correct topic based on params", %{registry: registry} do
      global_params = %{"region" => "global"}
      eu_params = %{"region" => "eu"}

      {:ok, ref_global} = Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, global_params)
      {:ok, ref_eu} = Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, eu_params)

      assert_receive {:reset, ^ref_global, _}
      assert_receive {:reset, ^ref_eu, _}

      # Unsubscribe from global
      :ok = Topical.unsubscribe(registry, ["leaderboards", "chess"], ref_global, global_params)

      # Add to global - ref_global should not receive (unsubscribed)
      Topical.execute(registry, ["leaderboards", "chess"], "add_score", {"alice", 100}, nil, global_params)
      refute_receive {:updates, ^ref_global, _}, 100

      # Add to EU - ref_eu should still receive
      Topical.execute(registry, ["leaderboards", "chess"], "add_score", {"bob", 200}, nil, eu_params)
      assert_receive {:updates, ^ref_eu, _}
    end
  end

  describe "capture with params" do
    test "capture uses params to find correct topic", %{registry: registry} do
      params = %{"region" => "asia"}

      # Create topic by subscribing
      {:ok, _ref} = Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, params)
      assert_receive {:reset, _, _}

      # Add a score
      Topical.execute(registry, ["leaderboards", "chess"], "add_score", {"yuki", 300}, nil, params)

      # Capture with same params should get the modified state
      {:ok, value} = Topical.capture(registry, ["leaderboards", "chess"], nil, params)
      assert value.region == "asia"
      assert length(value.entries) == 1
      assert hd(value.entries).player == "yuki"
    end
  end

  describe "notify with params" do
    test "notify targets correct topic based on params", %{registry: registry} do
      global_params = %{"region" => "global"}
      eu_params = %{"region" => "eu"}

      {:ok, ref_global} = Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, global_params)
      {:ok, ref_eu} = Topical.subscribe(registry, ["leaderboards", "chess"], self(), nil, eu_params)

      assert_receive {:reset, ^ref_global, _}
      assert_receive {:reset, ^ref_eu, _}

      # Notify on global leaderboard
      :ok = Topical.notify(registry, ["leaderboards", "chess"], "add_score", {"alice", 100}, nil, global_params)

      # Only global subscriber should receive update
      assert_receive {:updates, ^ref_global, _}
      refute_receive {:updates, ^ref_eu, _}, 100
    end
  end

  describe "topics without params" do
    test "topics without params work as before", %{registry: registry} do
      # CounterTopic has no params defined
      {:ok, ref} = Topical.subscribe(registry, ["counters", "1"], self())
      assert_receive {:reset, ^ref, %{count: 0}}

      {:ok, 1} = Topical.execute(registry, ["counters", "1"], "increment", {})
      assert_receive {:updates, ^ref, [{:set, [:count], 1}]}
    end

    test "passing params to topic without declared params ignores them", %{registry: registry} do
      # CounterTopic has no params, so these should be ignored
      params = %{"ignored" => "value"}

      {:ok, ref} = Topical.subscribe(registry, ["counters", "1"], self(), nil, params)
      assert_receive {:reset, ^ref, %{count: 0}}
    end
  end
end
