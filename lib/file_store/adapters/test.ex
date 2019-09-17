defmodule FileStore.Adapters.Test do
  @behaviour FileStore.Adapter

  use Agent
  alias FileStore.Stat

  @doc """
  Starts and agent for the test adapter.
  """
  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  @doc """
  Stops the agent for the test adapter.
  """
  def stop(reason \\ :normal, timeout \\ :infinity) do
    Agent.stop(__MODULE__, reason, timeout)
  end

  @doc """
  List all keys that have been uploaded.
  """
  def list_keys do
    Agent.get(__MODULE__, fn keys -> keys end)
  end

  @doc """
  Check if the given key is in state.
  """
  def has_key?(key) do
    Agent.get(__MODULE__, fn keys -> key in keys end)
  end

  @impl true
  def get_public_url(_store, key, _opts \\ []), do: key

  @impl true
  def get_signed_url(_store, key, _opts \\ []), do: {:ok, key}

  @impl true
  def stat(_store, key) do
    if has_key?(key) do
      {:ok, %Stat{key: key}}
    else
      {:error, :enoent}
    end
  end

  @impl true
  def write(_store, key, _content), do: put_key(key)

  @impl true
  def upload(_store, _source, key), do: put_key(key)

  @impl true
  def download(_store, key, _destination) do
    if has_key?(key), do: :ok, else: {:error, :enoent}
  end

  defp put_key(key) do
    Agent.update(__MODULE__, fn keys -> keys ++ [key] end)
  end
end
