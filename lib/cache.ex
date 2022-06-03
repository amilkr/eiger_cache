defmodule Cache do
  @moduledoc """
  Application API.

  It implements the 2 functions to register a function and to get a cached value.
  """

  @type register_function_result ::
          :ok
          | {:error, :already_registered}

  @type get_result ::
          {:ok, any()}
          | {:error, :timeout}
          | {:error, :not_registered}

  @doc """
  Registers a function that will be computed periodically to update the cache.

  Arguments:
    - `fun`: a 0-arity function that computes the value and returns either
      `{:ok, value}` or `{:error, reason}`.
    - `key`: associated with the function and is used to retrieve the stored
    value.
    - `ttl` ("time to live"): how long (in milliseconds) the value is stored
      before it is discarded if the value is not refreshed.
    - `refresh_interval`: how often (in milliseconds) the function is
      recomputed and the new value stored. `refresh_interval` must be strictly
      smaller than `ttl`. After the value is refreshed, the `ttl` counter is
      restarted.
  """
  @spec register_function(
          fun :: (() -> {:ok, any()} | {:error, any()}),
          key :: any(),
          ttl :: non_neg_integer(),
          refresh_interval :: non_neg_integer()
        ) :: register_function_result
  def register_function(fun, key, ttl, refresh_interval)
      when is_function(fun, 0) and is_integer(ttl) and ttl > 0 and
             is_integer(refresh_interval) and refresh_interval < ttl do
    Cache.Supervisor.start_child(fun, key, ttl, refresh_interval)
  end

  @doc """
  Get the value associated with `key`.

  Details:
    - If the value for `key` is stored in the cache, the value is returned
      immediately.
    - If a recomputation of the function is in progress, the last stored value
      is returned.
    - If the value for `key` is not stored in the cache but a computation of
      the function associated with this `key` is in progress, wait up to
      `timeout` milliseconds. If the value is computed within this interval,
      the value is returned. If the computation does not finish in this
      interval, `{:error, :timeout}` is returned.
    - If `key` is not associated with any function, return `{:error,
      :not_registered}`
  """
  @spec get(key :: any(), timeout :: non_neg_integer()) :: get_result
  def get(key, timeout \\ 30_000) when is_integer(timeout) and timeout > 0 do
    case Cache.Store.get(key) do
      {:ok, value} ->
        {:ok, value}

      {:error, :not_found} ->
        Cache.Worker.await_result(key, timeout)
    end
  end
end
