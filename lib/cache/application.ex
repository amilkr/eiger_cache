defmodule Cache.Application do
  @moduledoc """
  The Cache Application.
  """

  use Application

  @doc """
  Starts the main supervisor.
  """
  @spec start(any(), any()) :: {:ok, pid()} | {:error, any()}
  def start(_type, _args), do: Cache.Supervisor.start_link()
end
