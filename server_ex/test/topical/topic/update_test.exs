defmodule Topical.Topic.UpdateTest do
  use ExUnit.Case

  import Topical.Topic.Update

  test "set root value" do
    assert apply_update(%{foo: 1}, {:set, [], 2}) == 2
  end

  test "set new value" do
    assert apply_update(%{}, {:set, [:foo, :bar], 2}) == %{foo: %{bar: 2}}
  end

  test "set value within list" do
    assert apply_update(%{foo: [0, %{bar: 1}, 2]}, {:set, [:foo, 1, :bar], 3}) == %{
             foo: [0, %{bar: 3}, 2]
           }
  end

  test "replace existing value" do
    assert apply_update(%{foo: %{bar: 1, baz: 2}}, {:set, [:foo, :bar], 3}) == %{
             foo: %{bar: 3, baz: 2}
           }
  end

  test "unset value" do
    assert apply_update(%{foo: %{bar: 2}}, {:unset, [:foo], :bar}) == %{foo: %{}}
  end

  test "unset value within a list" do
    assert apply_update(%{foo: [0, %{bar: 1}, 2]}, {:unset, [:foo, 1], :bar}) == %{
             foo: [0, %{}, 2]
           }
  end

  test "reset value" do
    assert apply_update(%{foo: %{bar: 2}}, {:set, [], nil}) == nil
  end

  test "insert into list" do
    assert apply_update(%{foo: [0, 1, 2]}, {:insert, [:foo], 1, [3, 4]}) == %{
             foo: [0, 3, 4, 1, 2]
           }
  end

  test "delete from list" do
    assert apply_update(%{foo: [0, 1, 2, 3]}, {:delete, [:foo], 1, 2}) == %{foo: [0, 3]}
  end
end
