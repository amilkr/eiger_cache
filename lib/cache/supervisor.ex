defmodule Cache.Supervisor do
  @moduledoc """
  Main Supervisor.
  It's a Dynamic Supervisor responsible for starting and monitoring Worker processes.
  """

  use DynamicSupervisor

  @type start_child_result :: :ok | {:error, :already_registered}

  @spec start_link() :: {:ok, pid()} | {:error, any()}
  def start_link() do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec start_child(
          fun :: (() -> {:ok, any()} | {:error, any()}),
          key :: any,
          ttl :: non_neg_integer(),
          refresh_interval :: non_neg_integer()
        ) :: start_child_result
  def start_child(fun, key, ttl, refresh_interval) do
    args = %{
      fun: fun,
      key: key,
      ttl: ttl,
      refresh_interval: refresh_interval
    }

    case DynamicSupervisor.start_child(__MODULE__, {Cache.Worker, args}) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> {:error, :already_registered}
    end
  end

  @impl true
  def init([]) do
    :ok = Cache.Store.init()
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
