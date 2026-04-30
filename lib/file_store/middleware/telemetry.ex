defmodule FileStore.Middleware.Telemetry do
  @moduledoc """
  This middleware emits telemetry events for each operation.

  Add `:telemetry` to your dependencies before using this middleware:

      {:telemetry, "~> 1.0"}

  ## Usage

      store
      |> FileStore.Middleware.Telemetry.new()
      |> FileStore.write("foo", "hello")

  You can configure the event prefix and static metadata:

      store
      |> FileStore.Middleware.Telemetry.new(
        event_prefix: [:my_app, :file_store],
        metadata: %{tenant: "acme"}
      )

  ## Events

  Events are emitted for the following operations: `write`, `read`, `upload`,
  `download`, `stat`, `delete`, `delete_all`, `copy`, `rename`, `get_signed_url`,
  `put_access_control_list`, `set_tags`, `get_tags`.

  `get_public_url/3` and `list!/2` are passed through without instrumentation.
  `get_public_url/3` performs no I/O. `list!/2` returns a lazy stream — a span
  would close before any data is consumed.

  Each operation emits three events:

  | Event | When |
  |-------|------|
  | `[:file_store, <op>, :start]` | Before the operation |
  | `[:file_store, <op>, :stop]` | After the operation completes (success or error tuple) |
  | `[:file_store, <op>, :exception]` | If the operation raises |

  ### Measurements

  - `:duration` — wall time in native units (`:stop` and `:exception` only)
  - `:monotonic_time` — start time in native units (`:start` only)

  ### Metadata

  All events include these keys plus any static metadata from the constructor:

  | Key | Description |
  |-----|-------------|
  | `:operation` | Atom, e.g. `:write` |
  | `:key` | File key (single-key operations) |
  | `:src` | Source key (`copy`, `rename`) |
  | `:dest` | Destination key (`copy`, `rename`) |
  | `:opts` | Options passed to the operation |
  | `:content_size` | `byte_size/1` of content (`write` only) |
  | `:result` | `:ok` or `:error` (`:stop` only) |
  | `:error` | The error value (`:stop` only, when result is `:error`) |

  See the documentation for `FileStore.Middleware` for more information.
  """

  @enforce_keys [:__next__]
  defstruct [:__next__, event_prefix: [:file_store], metadata: %{}]

  @doc "Wrap a store with telemetry instrumentation."
  def new(store, opts \\ []) do
    opts =
      Keyword.update(opts, :metadata, %{}, fn
        m when is_map(m) -> m
        m -> Map.new(m)
      end)

    struct(__MODULE__, Keyword.put(opts, :__next__, store))
  end

  defimpl FileStore do
    def write(store, key, content, opts) do
      meta = build_meta(store, %{operation: :write, key: key, opts: opts, content_size: byte_size(content)})

      :telemetry.span(store.event_prefix ++ [:write], meta, fn ->
        case FileStore.write(store.__next__, key, content, opts) do
          :ok -> {:ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def read(store, key) do
      meta = build_meta(store, %{operation: :read, key: key})

      :telemetry.span(store.event_prefix ++ [:read], meta, fn ->
        case FileStore.read(store.__next__, key) do
          {:ok, _} = ok -> {ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def upload(store, source, key) do
      meta = build_meta(store, %{operation: :upload, key: key, source: source})

      :telemetry.span(store.event_prefix ++ [:upload], meta, fn ->
        case FileStore.upload(store.__next__, source, key) do
          :ok -> {:ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def download(store, key, destination) do
      meta = build_meta(store, %{operation: :download, key: key, destination: destination})

      :telemetry.span(store.event_prefix ++ [:download], meta, fn ->
        case FileStore.download(store.__next__, key, destination) do
          :ok -> {:ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def stat(store, key) do
      meta = build_meta(store, %{operation: :stat, key: key})

      :telemetry.span(store.event_prefix ++ [:stat], meta, fn ->
        case FileStore.stat(store.__next__, key) do
          {:ok, _} = ok -> {ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def delete(store, key) do
      meta = build_meta(store, %{operation: :delete, key: key})

      :telemetry.span(store.event_prefix ++ [:delete], meta, fn ->
        case FileStore.delete(store.__next__, key) do
          :ok -> {:ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def delete_all(store, opts) do
      meta = build_meta(store, %{operation: :delete_all, opts: opts})

      :telemetry.span(store.event_prefix ++ [:delete_all], meta, fn ->
        case FileStore.delete_all(store.__next__, opts) do
          :ok -> {:ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def copy(store, src, dest) do
      meta = build_meta(store, %{operation: :copy, src: src, dest: dest})

      :telemetry.span(store.event_prefix ++ [:copy], meta, fn ->
        case FileStore.copy(store.__next__, src, dest) do
          :ok -> {:ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def rename(store, src, dest) do
      meta = build_meta(store, %{operation: :rename, src: src, dest: dest})

      :telemetry.span(store.event_prefix ++ [:rename], meta, fn ->
        case FileStore.rename(store.__next__, src, dest) do
          :ok -> {:ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def get_signed_url(store, key, opts) do
      meta = build_meta(store, %{operation: :get_signed_url, key: key, opts: opts})

      :telemetry.span(store.event_prefix ++ [:get_signed_url], meta, fn ->
        case FileStore.get_signed_url(store.__next__, key, opts) do
          {:ok, _} = ok -> {ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def put_access_control_list(store, key, acl) do
      meta = build_meta(store, %{operation: :put_access_control_list, key: key, acl: acl})

      :telemetry.span(store.event_prefix ++ [:put_access_control_list], meta, fn ->
        case FileStore.put_access_control_list(store.__next__, key, acl) do
          :ok -> {:ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def set_tags(store, key, tags) do
      meta = build_meta(store, %{operation: :set_tags, key: key, tags: tags})

      :telemetry.span(store.event_prefix ++ [:set_tags], meta, fn ->
        case FileStore.set_tags(store.__next__, key, tags) do
          :ok -> {:ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def get_tags(store, key) do
      meta = build_meta(store, %{operation: :get_tags, key: key})

      :telemetry.span(store.event_prefix ++ [:get_tags], meta, fn ->
        case FileStore.get_tags(store.__next__, key) do
          {:ok, _} = ok -> {ok, Map.put(meta, :result, :ok)}
          {:error, err} = e -> {e, meta |> Map.put(:result, :error) |> Map.put(:error, err)}
        end
      end)
    end

    def get_public_url(store, key, opts) do
      FileStore.get_public_url(store.__next__, key, opts)
    end

    def list!(store, opts) do
      FileStore.list!(store.__next__, opts)
    end

    defp build_meta(store, fields), do: Map.merge(store.metadata, fields)
  end
end
