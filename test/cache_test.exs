defmodule CacheTest do
  use ExUnit.Case

  describe "register_function/4" do
    test "spawns a new worker when params are valid" do
      fun = fn -> {:ok, length(Process.list())} end
      key = :proc_count

      # Initial state: there's no worker registered for `key`
      assert :undefined = :global.whereis_name(key)

      # Register the function
      assert :ok = Cache.register_function(fun, key, 60_000, 10_000)

      # State after registration: 1 worker registered as {:global, key}
      assert key
             |> :global.whereis_name()
             |> is_pid()
    end

    test "returns {:error, :already_registered} when the key is already registered" do
      fun = fn -> {:ok, length(Process.list())} end
      key = "proc_count"

      # Register the function successfully
      assert :ok = Cache.register_function(fun, key, 60_000, 10_000)

      # Try to register a function with the same key fails
      assert {:error, :already_registered} = Cache.register_function(fun, key, 60_000, 10_000)
    end

    test "fails if params are invalid" do
      # When fun is not a function
      assert_raise FunctionClauseError, fn ->
        Cache.register_function(:notfun, :key, 60_000, 10_000)
      end

      # When fun arity is not 0
      assert_raise FunctionClauseError, fn ->
        Cache.register_function(fn n -> {:ok, n} end, :key, 60_000, 10_000)
      end

      # When ttl is not a non_neg_integer
      assert_raise FunctionClauseError, fn ->
        Cache.register_function(fn -> {:ok, :foo} end, :key, -60_000, -100_000)
      end

      # When refresh_interval is bigger than ttl
      assert_raise FunctionClauseError, fn ->
        Cache.register_function(fn -> {:ok, :foo} end, :key, 60_000, 100_000)
      end
    end
  end

  describe "get/2" do
    test "returns the cached value when it's available" do
      fun = fn -> {:ok, :foo} end
      key = :get_foo

      # Register the function
      :ok = Cache.register_function(fun, key, 60_000, 10_000)

      # Get cached data
      assert {:ok, :foo} = Cache.get(key)
    end

    test "returns {:error, :not_registered} when the key is not registered" do
      assert {:error, :not_registered} = Cache.get(:unregistered_key)
    end

    test "returns {:error, :timeout} if the fun takes too long to run and there's not cached data" do
      fun = fn -> {:ok, :timer.sleep(1_000)} end
      key = :get_long_run

      # Register the function
      :ok = Cache.register_function(fun, key, 60_000, 5_000)

      # Returns {:error, :timeout} when try to get cached data with a short timeout
      assert {:error, :timeout} = Cache.get(key, 100)

      # Returns {:ok, value} when try to get cached data with a timeout longer than the time the fun takes to run
      assert {:ok, :ok} = Cache.get(key, 1_500)
    end

    test "returns {:error, :timeout} if the fun constantly fails and can't update the store" do
      fun = fn -> {:error, :some_reason} end
      key = :get_error

      # Register the function
      :ok = Cache.register_function(fun, key, 60_000, 10)

      # Get cached data
      assert {:error, :timeout} = Cache.get(key, 100)
    end

    test "returns {:error, :timeout} when the cached data is expired
          because the registered function returns {:error, any()}" do
      pid = self()

      # Define a function that will succeed only once, i.e. it will update the cache once,
      # allowing it to expire after its ttl
      fun = fn ->
        case :global.register_name(:test_pid, pid) do
          :yes -> {:ok, :foo}
          :no -> {:error, :some_reason}
        end
      end

      key = :get_expired
      ttl = 100

      # Register the function
      :ok = Cache.register_function(fun, key, ttl, 50)

      # Get cached data immediately (i.e. before it expires)
      assert {:ok, :foo} = Cache.get(key, 100)

      # Get cached data after `ttl + 1` milliseconds (i.e. after it expired)
      :ok = :timer.sleep(ttl + 1)
      assert {:error, :timeout} = Cache.get(key, 100)
    end

    test "returns {:error, :timeout} when the cached data is expired
          because the registered function returns an invalid result" do
      # Define a function that will succeed only once, i.e. it will update the cache once,
      # allowing it to expire after its ttl
      fun = fn ->
        result = Application.get_env(Cache, :fun_result, {:ok, :foo})
        :ok = Application.put_env(Cache, :fun_result, :invalid_result_format)
        result
      end

      key = :get_invalid_result
      ttl = 100

      # Register the function
      :ok = Cache.register_function(fun, key, ttl, 50)

      # Get cached data immediately (i.e. before it expires)
      assert {:ok, :foo} = Cache.get(key, 100)

      # Get cached data after `ttl + 1` milliseconds (i.e. after it expired)
      :ok = :timer.sleep(ttl + 1)
      assert {:error, :timeout} = Cache.get(key, 100)
    end
  end
end
