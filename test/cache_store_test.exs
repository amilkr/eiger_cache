defmodule Cache.StoreTest do
  use ExUnit.Case

  alias Cache.Store

  describe "store/2 and get/2" do
    test "store and get a value successfully" do
      key = :foo
      value = :bar
      ttl = 1_000

      assert {:error, :not_found} = Store.get(key)
      assert :ok = Store.store(key, value, ttl)
      assert {:ok, ^value} = Store.get(key)
    end

    test "expired objects are not returned" do
      key = :foo
      value = :bar
      ttl = 100

      assert :ok = Store.store(key, value, ttl)
      assert {:ok, ^value} = Store.get(key)

      # Wait for expiration
      :timer.sleep(ttl + 1)

      assert {:error, :not_found} = Store.get(key)
    end
  end
end
