defmodule Cache.WorkerTest do
  use ExUnit.Case

  alias Cache.Store
  alias Cache.Worker

  describe "start_link/1" do
    test "accepts any type of key" do
      [
        500,
        :an_atom,
        "a string",
        {:a, "tuple"},
        %{a: "map"},
        [a: "keyword"],
        fn -> "a function" end
      ]
      |> Enum.each(fn key ->
        assert {:ok, pid} =
                 Worker.start_link(%{
                   fun: fn -> {:ok, :foo} end,
                   key: key,
                   ttl: 1_000,
                   refresh_interval: 500
                 })

        assert ^pid = :global.whereis_name(key)
      end)
    end

    test "starts a new process that executes the function
          and updates the store if the function returns {:ok, any()}" do
      key = :start_link
      value = :foo

      assert {:ok, _pid} =
               Worker.start_link(%{
                 fun: fn -> {:ok, value} end,
                 key: key,
                 ttl: 1_000,
                 refresh_interval: 500
               })

      assert {:ok, ^value} = Worker.await_result(key, 1_000)
      assert {:ok, ^value} = Store.get(key)
    end

    test "doesn't update the store if the function returns {:error, any()}" do
      key = :start_link_error

      assert {:ok, _pid} =
               Worker.start_link(%{
                 fun: fn -> {:error, :reason} end,
                 key: key,
                 ttl: 10_000,
                 refresh_interval: 500
               })

      assert {:error, :timeout} = Worker.await_result(key, 600)
      assert {:error, :not_found} = Store.get(key)
    end

    test "doesn't update the store if the function returns an invalid response" do
      key = :start_link_invalid

      assert {:ok, _pid} =
               Worker.start_link(%{
                 fun: fn -> :invalid_format end,
                 key: key,
                 ttl: 10_000,
                 refresh_interval: 500
               })

      assert {:error, :timeout} = Worker.await_result(key, 600)
      assert {:error, :not_found} = Store.get(key)
    end
  end

  describe "await_result/2" do
    setup do
      key = "await result"
      value = :foo
      refresh_interval = 2_000

      {:ok, _pid} =
        Worker.start_link(%{
          fun: fn -> {:ok, value} end,
          key: key,
          ttl: 10_000,
          refresh_interval: refresh_interval
        })

      %{
        key: key,
        value: value,
        refresh_interval: refresh_interval
      }
    end

    test "returns next result when the next function execution finishes before the timeout", ctx do
      value = ctx.value
      timeout = ctx.refresh_interval * 2
      assert {:ok, ^value} = Worker.await_result(ctx.key, timeout)
    end

    test "returns {:error, :not_registered} when there's not worker for key" do
      assert {:error, :not_registered} = Worker.await_result(:invalid_key, 1_000)
    end

    test "returns {:error, :timeout} when the next function execution takes longer than timeout", ctx do
      assert {:error, :timeout} = Worker.await_result(ctx.key, 1)
    end
  end
end
