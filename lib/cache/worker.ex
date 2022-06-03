defmodule Cache.Worker do
  @moduledoc """
  Implements the process worker (as a gen_sever) for each registered function.
  """
  require Logger

  use GenServer

  @doc """
  It spawns a new worker that will execute the registered :fun every :refresh_interval,
  and it will store the result in Cache.Store.
  """
  @spec start_link(%{
          fun: (() -> {:ok, any()} | {:error, any()}),
          key: any(),
          ttl: non_neg_integer(),
          refresh_interval: non_neg_integer()
        }) :: {:ok, pid()} | {:error, any()}
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: {:global, args.key})
  end

  @spec await_result(
          key :: any(),
          timeout :: non_neg_integer()
        ) :: {:ok, any()} | {:error, :timeout | :not_registered}
  def await_result(key, timeout) do
    case :global.whereis_name(key) do
      pid when is_pid(pid) ->
        GenServer.call(pid, :await_result, timeout)

      :undefined ->
        {:error, :not_registered}
    end
  end

  @impl true
  def init(args) do
    Process.send(self(), :work, [])
    state = Map.put(args, :clients_awaiting_result, [])

    {:ok, state}
  end

  @impl true
  def handle_call(:await_result, from, state) do
    state = Map.update!(state, :clients_awaiting_result, &([from | &1]))

    {:noreply, state}
  end

  @impl true
  def handle_info(:work, state) do
    work(state)

    # Schedule next iteration
    Process.send_after(self(), :work, state.refresh_interval)

    {:noreply, state}
  end

  def handle_info({:notify_result, result}, state) do
    # Send the result to each client waiting for the result
    Enum.each(state.clients_awaiting_result, fn client ->
      GenServer.reply(client, {:ok, result})
    end)

    # Refresh the :clients_awaiting_result list
    state = Map.put(state, :clients_awaiting_result, [])

    {:noreply, state}
  end

  ## Private Functions

  defp work(state) do
    # Execute the registered function
    case state.fun.() do
      {:ok, result} ->
        # Store the execution result
        Cache.Store.store(state.key, result, state.ttl)

        # Send a message to self to notify the result to the clients waiting for it.
        #
        # The trick here is that the worker will handle this message after handling all
        # the pending :await_result messages.
        # Which means that all the clients waiting for the result will be part
        # of the :clients_awaiting_result list, it doesn't matter if they called await_result/2
        # before or after the worker started executing the registered function.
        Process.send(self(), {:notify_result, result}, [])

      {:error, reason} ->
        Logger.warn("#{inspect(state.key)} failed with reason: #{inspect(reason)}")

      error ->
        Logger.error("#{inspect(state.key)} returned an invalid result: #{inspect(error)}")
    end
  end
end
