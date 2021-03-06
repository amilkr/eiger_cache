defmodule Cache.Store do
  @moduledoc """
  Module responsible for storing and retrieving cache data.

  It uses an ETS as data store. The ETS is created with these options:

  * `named_table` to allow to reference it by its name (instead of its tid)
  * `public` to allow any process (`Cache.Worker`s) to insert and read objects
  * `{:read_concurrency, true}` because the app aims to be used on situations
  where concurrent read operations are much more frequent than write operations
  """

  @table_name __MODULE__

  @doc """
  Creates the ETS where the cached data will be stored.
  """
  @spec init() :: :ok
  def init do
    @table_name = :ets.new(@table_name, [:named_table, :public, {:read_concurrency, true}])
    :ok
  end

  @doc """
  It stores a new object in the ETS.

  The object is a 3-tuple where:
    * the 1st element is `key`
    * the 2nd element is the expiration datetime (`DateTime.add(DateTime.utc_now(), ttl, :millisecond)`)
    * the 3rd element is `value`
  """
  @spec store(key :: any(), value :: any(), ttl :: non_neg_integer()) :: :ok
  def store(key, value, ttl) do
    expires_at = DateTime.add(DateTime.utc_now(), ttl, :millisecond)
    true = :ets.insert(@table_name, {key, expires_at, value})
    :ok
  end

  @doc """
  It fetches and returns a value by key.

  If the key doesn't exist in the table or the `expires_at` field is older
  than the current time, it returns `{:error, :not_found}`.
  """
  @spec get(key :: any()) :: {:ok, any()} | {:error, :not_found}
  def get(key) do
    with [{_key, expires_at, value}] <- :ets.lookup(@table_name, key),
         false <- is_expired?(expires_at) do
      {:ok, value}
    else
      _ -> {:error, :not_found}
    end
  end

  ## Private Functions

  defp is_expired?(expires_at), do: DateTime.compare(expires_at, DateTime.utc_now()) == :lt
end
