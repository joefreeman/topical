defmodule Topical.TopicTest do
  use ExUnit.Case

  alias Topical.Topic

  describe "new/2" do
    test "creates topic with value only" do
      topic = Topic.new(%{foo: 1})

      assert topic.value == %{foo: 1}
      assert topic.state == nil
      assert topic.updates == []
    end

    test "creates topic with value and state" do
      topic = Topic.new(%{foo: 1}, %{bar: 2})

      assert topic.value == %{foo: 1}
      assert topic.state == %{bar: 2}
      assert topic.updates == []
    end

    test "creates topic with nil value" do
      topic = Topic.new(nil)

      assert topic.value == nil
      assert topic.state == nil
    end

    test "creates topic with list value" do
      topic = Topic.new([1, 2, 3])

      assert topic.value == [1, 2, 3]
    end
  end

  describe "set/3" do
    test "sets value at root path" do
      topic = Topic.new(%{foo: 1})
      topic = Topic.set(topic, [], %{bar: 2})

      assert topic.value == %{bar: 2}
      assert topic.updates == [{:set, [], %{bar: 2}}]
    end

    test "sets value at nested path" do
      topic = Topic.new(%{foo: %{bar: 1}})
      topic = Topic.set(topic, [:foo, :bar], 2)

      assert topic.value == %{foo: %{bar: 2}}
      assert topic.updates == [{:set, [:foo, :bar], 2}]
    end

    test "sets value at new path" do
      topic = Topic.new(%{foo: %{}})
      topic = Topic.set(topic, [:foo, :bar], 1)

      assert topic.value == %{foo: %{bar: 1}}
      assert topic.updates == [{:set, [:foo, :bar], 1}]
    end

    test "sets value with atom key" do
      topic = Topic.new(%{})
      topic = Topic.set(topic, [:foo], 1)

      assert topic.value == %{foo: 1}
    end

    test "sets value within list" do
      topic = Topic.new(%{items: [%{id: 1}, %{id: 2}]})
      topic = Topic.set(topic, [:items, 0, :id], 10)

      assert topic.value == %{items: [%{id: 10}, %{id: 2}]}
    end

    test "tracks multiple updates" do
      topic =
        %{a: 1, b: 2}
        |> Topic.new()
        |> Topic.set([:a], 10)
        |> Topic.set([:b], 20)

      assert topic.value == %{a: 10, b: 20}
      assert topic.updates == [{:set, [:b], 20}, {:set, [:a], 10}]
    end
  end

  describe "unset/3" do
    test "unsets key from map" do
      topic = Topic.new(%{foo: %{bar: 1, baz: 2}})
      topic = Topic.unset(topic, [:foo], :bar)

      assert topic.value == %{foo: %{baz: 2}}
      assert topic.updates == [{:unset, [:foo], :bar}]
    end

    test "unsets key from nested map" do
      topic = Topic.new(%{foo: %{bar: %{a: 1, b: 2}}})
      topic = Topic.unset(topic, [:foo, :bar], :a)

      assert topic.value == %{foo: %{bar: %{b: 2}}}
    end

    test "unsets key from root" do
      topic = Topic.new(%{foo: 1, bar: 2})
      topic = Topic.unset(topic, [], :foo)

      assert topic.value == %{bar: 2}
    end
  end

  describe "insert/4" do
    test "inserts single value at end of list" do
      topic = Topic.new(%{items: [1, 2]})
      topic = Topic.insert(topic, [:items], 3)

      assert topic.value == %{items: [1, 2, 3]}
      assert topic.updates == [{:insert, [:items], nil, [3]}]
    end

    test "inserts single value at specific index" do
      topic = Topic.new(%{items: [1, 3]})
      topic = Topic.insert(topic, [:items], 1, 2)

      assert topic.value == %{items: [1, 2, 3]}
      assert topic.updates == [{:insert, [:items], 1, [2]}]
    end

    test "inserts multiple values at end" do
      topic = Topic.new(%{items: [1]})
      topic = Topic.insert(topic, [:items], [2, 3])

      assert topic.value == %{items: [1, 2, 3]}
      assert topic.updates == [{:insert, [:items], nil, [2, 3]}]
    end

    test "inserts multiple values at specific index" do
      topic = Topic.new(%{items: [1, 4]})
      topic = Topic.insert(topic, [:items], 1, [2, 3])

      assert topic.value == %{items: [1, 2, 3, 4]}
      assert topic.updates == [{:insert, [:items], 1, [2, 3]}]
    end

    test "inserts at beginning with index 0" do
      topic = Topic.new(%{items: [2, 3]})
      topic = Topic.insert(topic, [:items], 0, 1)

      assert topic.value == %{items: [1, 2, 3]}
    end

    test "does not add update for empty list" do
      topic = Topic.new(%{items: [1, 2]})
      topic = Topic.insert(topic, [:items], [])

      assert topic.value == %{items: [1, 2]}
      assert topic.updates == []
    end

    test "inserts into nested list" do
      topic = Topic.new(%{foo: %{bar: [1, 2]}})
      topic = Topic.insert(topic, [:foo, :bar], 3)

      assert topic.value == %{foo: %{bar: [1, 2, 3]}}
    end
  end

  describe "delete/4" do
    test "deletes single element from list" do
      topic = Topic.new(%{items: [1, 2, 3]})
      topic = Topic.delete(topic, [:items], 1)

      assert topic.value == %{items: [1, 3]}
      assert topic.updates == [{:delete, [:items], 1, 1}]
    end

    test "deletes multiple elements from list" do
      topic = Topic.new(%{items: [1, 2, 3, 4]})
      topic = Topic.delete(topic, [:items], 1, 2)

      assert topic.value == %{items: [1, 4]}
      assert topic.updates == [{:delete, [:items], 1, 2}]
    end

    test "deletes from beginning of list" do
      topic = Topic.new(%{items: [1, 2, 3]})
      topic = Topic.delete(topic, [:items], 0)

      assert topic.value == %{items: [2, 3]}
    end

    test "deletes from end of list" do
      topic = Topic.new(%{items: [1, 2, 3]})
      topic = Topic.delete(topic, [:items], 2)

      assert topic.value == %{items: [1, 2]}
    end

    test "deletes from nested list" do
      topic = Topic.new(%{foo: %{bar: [1, 2, 3]}})
      topic = Topic.delete(topic, [:foo, :bar], 0)

      assert topic.value == %{foo: %{bar: [2, 3]}}
    end
  end

  describe "merge/3" do
    test "merges map into existing map" do
      topic = Topic.new(%{data: %{a: 1, b: 2}})
      topic = Topic.merge(topic, [:data], %{b: 3, c: 4})

      assert topic.value == %{data: %{a: 1, b: 3, c: 4}}
      assert topic.updates == [{:merge, [:data], %{b: 3, c: 4}}]
    end

    test "merges into empty map" do
      topic = Topic.new(%{data: %{}})
      topic = Topic.merge(topic, [:data], %{a: 1})

      assert topic.value == %{data: %{a: 1}}
    end

    test "merges into nil (creates map)" do
      topic = Topic.new(%{data: nil})
      topic = Topic.merge(topic, [:data], %{a: 1})

      assert topic.value == %{data: %{a: 1}}
    end

    test "merges at root" do
      topic = Topic.new(%{a: 1, b: 2})
      topic = Topic.merge(topic, [], %{b: 3, c: 4})

      assert topic.value == %{a: 1, b: 3, c: 4}
    end

    test "merges at nested path" do
      topic = Topic.new(%{foo: %{bar: %{a: 1}}})
      topic = Topic.merge(topic, [:foo, :bar], %{b: 2})

      assert topic.value == %{foo: %{bar: %{a: 1, b: 2}}}
    end
  end

  describe "chained operations" do
    test "supports chaining multiple different operations" do
      topic =
        %{users: %{}, order: []}
        |> Topic.new()
        |> Topic.set([:users, "1"], %{name: "Alice"})
        |> Topic.insert([:order], "1")
        |> Topic.set([:users, "2"], %{name: "Bob"})
        |> Topic.insert([:order], "2")
        |> Topic.merge([:users, "1"], %{age: 30})

      assert topic.value == %{
               users: %{"1" => %{name: "Alice", age: 30}, "2" => %{name: "Bob"}},
               order: ["1", "2"]
             }

      # Updates are in reverse order
      assert length(topic.updates) == 5
    end

    test "state is preserved through operations" do
      topic = Topic.new(%{count: 0}, %{id: "test"})
      topic = Topic.set(topic, [:count], 1)
      topic = Topic.set(topic, [:count], 2)

      assert topic.state == %{id: "test"}
      assert topic.value.count == 2
    end
  end
end
