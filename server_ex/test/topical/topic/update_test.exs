defmodule Topical.Topic.UpdateTest do
  use ExUnit.Case

  alias Topical.Topic.Update

  test "set root value" do
    assert Update.apply(%{foo: 1}, {:set, [], 2}) == 2
  end

  test "set new value" do
    assert Update.apply(%{}, {:set, [:foo, :bar], 2}) == %{foo: %{bar: 2}}
  end

  test "set value within list" do
    assert Update.apply(%{foo: [0, %{bar: 1}, 2]}, {:set, [:foo, 1, :bar], 3}) == %{
             foo: [0, %{bar: 3}, 2]
           }
  end

  test "replace existing value" do
    assert Update.apply(%{foo: %{bar: 1, baz: 2}}, {:set, [:foo, :bar], 3}) == %{
             foo: %{bar: 3, baz: 2}
           }
  end

  test "unset value" do
    assert Update.apply(%{foo: %{bar: 2}}, {:unset, [:foo], :bar}) == %{foo: %{}}
  end

  test "unset value within a list" do
    assert Update.apply(%{foo: [0, %{bar: 1}, 2]}, {:unset, [:foo, 1], :bar}) == %{
             foo: [0, %{}, 2]
           }
  end

  test "reset value" do
    assert Update.apply(%{foo: %{bar: 2}}, {:set, [], nil}) == nil
  end

  test "insert into list" do
    assert Update.apply(%{foo: [0, 1, 2]}, {:insert, [:foo], 1, [3, 4]}) == %{
             foo: [0, 3, 4, 1, 2]
           }
  end

  test "delete from list" do
    assert Update.apply(%{foo: [0, 1, 2, 3]}, {:delete, [:foo], 1, 2}) == %{foo: [0, 3]}
  end

  test "merge value" do
    assert Update.apply(%{foo: %{bar: %{a: 1, b: 2}}}, {:merge, [:foo, :bar], %{b: 3, c: 4}}) ==
             %{foo: %{bar: %{a: 1, b: 3, c: 4}}}
  end

  test "merge non-existing value" do
    assert Update.apply(%{foo: %{}}, {:merge, [:foo, :bar], %{a: 1}}) == %{foo: %{bar: %{a: 1}}}
  end
end
