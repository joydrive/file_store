defmodule FileStore.Adapters.Memory do
  @moduledoc """
  Stores files in memory. This adapter is particularly
  useful in tests.

  ### Configuration

    * `name` - The name used to register the process.

    * `base_url` - The base URL that should be used for
       generating URLs to your files.

  ### Example

      iex> store = FileStore.Adapters.Memory.new(base_url: "http://example.com/files/")
      %FileStore.Adapters.Memory{...}

      iex> FileStore.write(store, "foo", "hello world")
      :ok

      iex> FileStore.read(store, "foo")
      {:ok, "hello world"}

  ### Usage in tests

      defmodule MyTest do
        use ExUnit.Case

        setup do
          start_supervised!(FileStore.Adapters.Memory)
          :ok
        end

        test "writes a file" do
          store = FileStore.Adapters.Memory.new()
          assert :ok = FileStore.write(store, "foo", "bar")
          assert {:ok, "bar"} = FileStore.read(store, "foo")
        end
      end

  """

  use Agent

  @enforce_keys [:base_url]
  defstruct [:base_url, name: __MODULE__]

  defmodule Object do
    @moduledoc false
    defstruct [:content, tags: []]
  end

  @doc "Creates a new memory adapter"
  @spec new(keyword) :: FileStore.t()
  def new(opts) do
    if is_nil(opts[:base_url]) do
      raise "missing configuration: :base_url"
    end

    struct(__MODULE__, opts)
  end

  @doc "Starts an agent for the test adapter."
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> %{} end, name: name)
  end

  @doc "Stops the agent for the test adapter."
  def stop(store, reason \\ :normal, timeout \\ :infinity) do
    Agent.stop(store.name, reason, timeout)
  end

  defimpl FileStore do
    alias FileStore.Adapters.Memory.Object
    alias FileStore.Error.Classifier
    alias FileStore.Stat
    alias FileStore.Utils

    def get_public_url(store, key, opts) do
      query = Keyword.take(opts, [:content_type, :disposition])

      store.base_url
      |> URI.parse()
      |> Utils.append_path(key)
      |> Utils.put_query(query)
      |> URI.to_string()
    end

    def get_signed_url(store, key, opts) do
      {:ok, get_public_url(store, key, opts)}
    end

    def stat(store, key) do
      store.name
      |> Agent.get(&Map.fetch(&1, key))
      |> case do
        {:ok, %Object{content: content}} ->
          {
            :ok,
            %Stat{
              key: key,
              size: byte_size(content),
              etag: Stat.checksum(content),
              type: "application/octet-stream"
            }
          }

        :error ->
          {:error, :enoent}
      end
      |> wrap_error(operation: :stat, key: key)
    end

    def delete(store, key) do
      Agent.update(store.name, &Map.delete(&1, key))
    end

    def delete_all(store, opts) do
      prefix = Keyword.get(opts, :prefix, "")

      Agent.update(store.name, fn state ->
        state
        |> Enum.reject(fn {key, _} -> String.starts_with?(key, prefix) end)
        |> Map.new()
      end)
    end

    def write(store, key, content, _opts \\ []) do
      Agent.update(store.name, &Map.put(&1, key, %Object{content: content}))
    end

    def read(store, key) do
      Agent.get(store.name, fn state ->
        case Map.fetch(state, key) do
          {:ok, %Object{content: content}} -> {:ok, content}
          :error -> {:error, :enoent}
        end
      end)
      |> wrap_error(operation: :read, key: key)
    end

    def copy(store, src, dest) do
      Agent.get_and_update(store.name, fn state ->
        case Map.fetch(state, src) do
          {:ok, value} ->
            {:ok, Map.put(state, dest, value)}

          :error ->
            {{:error, :enoent}, state}
        end
      end)
      |> wrap_error(operation: :copy, src: src, dest: dest)
    end

    def rename(store, src, dest) do
      Agent.get_and_update(store.name, fn state ->
        case Map.fetch(state, src) do
          {:ok, value} ->
            {:ok, state |> Map.delete(src) |> Map.put(dest, value)}

          :error ->
            {{:error, :enoent}, state}
        end
      end)
      |> wrap_error(operation: :rename, src: src, dest: dest)
    end

    def put_access_control_list(_store, _key, _acl), do: :ok

    def set_tags(store, key, tags) do
      Agent.get_and_update(store.name, fn state ->
        case Map.fetch(state, key) do
          {:ok, %Object{content: content}} ->
            {:ok, Map.put(state, key, %Object{content: content, tags: tags})}

          :error ->
            {{:error, :enoent}, state}
        end
      end)
      |> wrap_error(operation: :set_tags, key: key, tags: tags)
    end

    def get_tags(store, key) do
      Agent.get(store.name, fn state ->
        case Map.fetch(state, key) do
          {:ok, %Object{tags: tags}} ->
            {:ok, tags}

          :error ->
            {:error, :enoent}
        end
      end)
      |> wrap_error(operation: :get_tags, key: key)
    end

    def upload(store, source, key) do
      with {:ok, data} <- File.read(source) do
        write(store, key, data)
      end
      |> wrap_error(operation: :upload, path: source, key: key)
    end

    def download(store, key, destination) do
      store.name
      |> Agent.get(&Map.fetch(&1, key))
      |> case do
        {:ok, %Object{content: content}} -> File.write(destination, content)
        :error -> {:error, :enoent}
      end
      |> wrap_error(operation: :download, key: key, path: destination)
    end

    def list!(store, opts) do
      prefix = Keyword.get(opts, :prefix, "")

      store.name
      |> Agent.get(&Map.keys/1)
      |> Stream.filter(&String.starts_with?(&1, prefix))
    end

    defp wrap_error(:ok, _ctx), do: :ok
    defp wrap_error({:ok, _} = ok, _ctx), do: ok
    defp wrap_error({:error, reason}, ctx), do: {:error, Classifier.classify(reason, ctx)}
  end
end
