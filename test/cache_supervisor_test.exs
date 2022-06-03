defmodule Cache.SupervisorTest do
  use ExUnit.Case

  describe "start_child/4" do
    test "starts a new child when there's not process for that key" do
      fun = fn -> {:ok, length(Process.list())} end
      key = :start_child

      # Initial children count
      %{active: children_count} = DynamicSupervisor.count_children(Cache.Supervisor)

      # Register the function
      assert :ok = Cache.register_function(fun, key, 60_000, 10_000)

      # Children count after the registration
      %{active: new_children_count} = DynamicSupervisor.count_children(Cache.Supervisor)

      assert ^new_children_count = children_count + 1
    end

    test "returns {:error, :already_registered} when there's already a process for that key" do
      fun = fn -> {:ok, length(Process.list())} end
      key = :child_already_registered

      # Register the function successfully
      assert :ok = Cache.register_function(fun, key, 60_000, 10_000)

      # Second registration fails
      assert {:error, :already_registered} = Cache.register_function(fun, key, 60_000, 10_000)
    end
  end
end
