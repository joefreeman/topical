defmodule Topical.ProtocolTest do
  use ExUnit.Case

  alias Topical.Protocol.{Request, Response}

  describe "Request.decode/1" do
    test "decodes notify request" do
      json = Jason.encode!([0, ["lists", "1"], "add", ["test"]])

      assert {:ok, :notify, ["lists", "1"], "add", ["test"]} = Request.decode(json)
    end

    test "decodes execute request" do
      json = Jason.encode!([1, "ch1", ["counters", "1"], "increment", []])

      assert {:ok, :execute, "ch1", ["counters", "1"], "increment", []} = Request.decode(json)
    end

    test "decodes subscribe request" do
      json = Jason.encode!([2, "ch1", ["lists", "abc"]])

      assert {:ok, :subscribe, "ch1", ["lists", "abc"]} = Request.decode(json)
    end

    test "decodes unsubscribe request" do
      json = Jason.encode!([3, "ch1"])

      assert {:ok, :unsubscribe, "ch1"} = Request.decode(json)
    end

    test "returns error for unrecognised command" do
      json = Jason.encode!([99, "unknown"])

      assert {:error, :unrecognised_command} = Request.decode(json)
    end

    test "returns error for invalid array" do
      json = Jason.encode!([0])

      assert {:error, :unrecognised_command} = Request.decode(json)
    end

    test "returns error for invalid JSON" do
      assert {:error, :decode_failure} = Request.decode("not json")
    end

    test "returns error for non-array JSON" do
      json = Jason.encode!(%{type: 0})

      assert {:error, :unrecognised_command} = Request.decode(json)
    end

    test "decodes notify with complex args" do
      args = %{"name" => "Test", "items" => [1, 2, 3]}
      json = Jason.encode!([0, ["topic"], "action", args])

      assert {:ok, :notify, ["topic"], "action", ^args} = Request.decode(json)
    end

    test "decodes execute with string channel_id" do
      json = Jason.encode!([1, "channel-123", ["topic"], "action", []])

      assert {:ok, :execute, "channel-123", ["topic"], "action", []} = Request.decode(json)
    end

    test "decodes execute with integer channel_id" do
      json = Jason.encode!([1, 42, ["topic"], "action", []])

      assert {:ok, :execute, 42, ["topic"], "action", []} = Request.decode(json)
    end
  end

  describe "Response.encode_error/2" do
    test "encodes error response" do
      result = Response.encode_error("ch1", "not_found")

      assert Jason.decode!(result) == [0, "ch1", "not_found"]
    end

    test "encodes error with complex error object" do
      error = %{"code" => 403, "message" => "Forbidden"}
      result = Response.encode_error("ch1", error)

      assert Jason.decode!(result) == [0, "ch1", error]
    end
  end

  describe "Response.encode_result/2" do
    test "encodes result response" do
      result = Response.encode_result("ch1", 42)

      assert Jason.decode!(result) == [1, "ch1", 42]
    end

    test "encodes complex result" do
      data = %{"id" => "123", "name" => "Test"}
      result = Response.encode_result("ch1", data)

      assert Jason.decode!(result) == [1, "ch1", data]
    end

    test "encodes null result" do
      result = Response.encode_result("ch1", nil)

      assert Jason.decode!(result) == [1, "ch1", nil]
    end

    test "encodes list result" do
      result = Response.encode_result("ch1", [1, 2, 3])

      assert Jason.decode!(result) == [1, "ch1", [1, 2, 3]]
    end
  end

  describe "Response.encode_topic_reset/2" do
    test "encodes topic reset" do
      value = %{"count" => 0}
      result = Response.encode_topic_reset("ch1", value)

      assert Jason.decode!(result) == [2, "ch1", value]
    end

    test "encodes reset with complex value" do
      value = %{"items" => [], "order" => [], "meta" => %{"created" => "2024-01-01"}}
      result = Response.encode_topic_reset("ch1", value)

      assert Jason.decode!(result) == [2, "ch1", value]
    end
  end

  describe "Response.encode_topic_updates/2" do
    test "encodes set update" do
      updates = [{:set, [:count], 5}]
      result = Response.encode_topic_updates("ch1", updates)

      assert Jason.decode!(result) == [3, "ch1", [[0, ["count"], 5]]]
    end

    test "encodes unset update" do
      updates = [{:unset, [:data], :key}]
      result = Response.encode_topic_updates("ch1", updates)

      assert Jason.decode!(result) == [3, "ch1", [[1, ["data"], "key"]]]
    end

    test "encodes insert update" do
      updates = [{:insert, [:items], 0, ["a", "b"]}]
      result = Response.encode_topic_updates("ch1", updates)

      assert Jason.decode!(result) == [3, "ch1", [[2, ["items"], 0, ["a", "b"]]]]
    end

    test "encodes insert update with nil index (append)" do
      updates = [{:insert, [:items], nil, ["new"]}]
      result = Response.encode_topic_updates("ch1", updates)

      assert Jason.decode!(result) == [3, "ch1", [[2, ["items"], nil, ["new"]]]]
    end

    test "encodes delete update" do
      updates = [{:delete, [:items], 2, 1}]
      result = Response.encode_topic_updates("ch1", updates)

      assert Jason.decode!(result) == [3, "ch1", [[3, ["items"], 2, 1]]]
    end

    test "encodes merge update" do
      updates = [{:merge, [:data], %{a: 1}}]
      result = Response.encode_topic_updates("ch1", updates)

      decoded = Jason.decode!(result)
      assert [3, "ch1", [[4, ["data"], %{"a" => 1}]]] = decoded
    end

    test "encodes multiple updates" do
      updates = [
        {:set, [:a], 1},
        {:set, [:b], 2},
        {:unset, [:c], :d}
      ]

      result = Response.encode_topic_updates("ch1", updates)
      decoded = Jason.decode!(result)

      assert [3, "ch1", encoded_updates] = decoded
      assert length(encoded_updates) == 3
    end

    test "encodes empty updates list" do
      updates = []
      result = Response.encode_topic_updates("ch1", updates)

      assert Jason.decode!(result) == [3, "ch1", []]
    end

    test "encodes update with nested path" do
      updates = [{:set, [:users, "123", :name], "Alice"}]
      result = Response.encode_topic_updates("ch1", updates)

      assert Jason.decode!(result) == [3, "ch1", [[0, ["users", "123", "name"], "Alice"]]]
    end

    test "encodes update with integer index in path" do
      updates = [{:set, [:items, 0, :done], true}]
      result = Response.encode_topic_updates("ch1", updates)

      assert Jason.decode!(result) == [3, "ch1", [[0, ["items", 0, "done"], true]]]
    end
  end
end
