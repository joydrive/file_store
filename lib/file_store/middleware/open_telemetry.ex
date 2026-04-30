defmodule FileStore.Middleware.OpenTelemetry do
  @moduledoc """
  This middleware creates OpenTelemetry spans for each operation.

  Add `:opentelemetry_api` to your dependencies before using this middleware:

      {:opentelemetry_api, "~> 1.3"}

  You also need an OpenTelemetry SDK configured in your application (e.g.
  `:opentelemetry`) to export spans. The middleware only calls the API layer.

  ## Usage

      store
      |> FileStore.Middleware.OpenTelemetry.new()
      |> FileStore.write("foo", "hello")

  You can configure the span name prefix and static attributes:

      store
      |> FileStore.Middleware.OpenTelemetry.new(
        span_prefix: "my_app.storage.",
        attributes: %{"service.name" => "file-service"}
      )

  ## Spans

  Spans are created for the following operations: `write`, `read`, `upload`,
  `download`, `stat`, `delete`, `delete_all`, `copy`, `rename`, `get_signed_url`,
  `put_access_control_list`, `set_tags`, `get_tags`.

  `get_public_url/3` and `list!/2` are passed through without instrumentation.
  `get_public_url/3` performs no I/O. `list!/2` returns a lazy stream — a span
  would close before any data is consumed.

  Span names follow the pattern `"file_store.<operation>"` (configurable via
  `:span_prefix`). All spans use kind `:client`.

  ### Attributes

  | Attribute | Description |
  |-----------|-------------|
  | `code.function` | Operation name, e.g. `"write"` |
  | `file_store.key` | File key (single-key operations) |
  | `file_store.src` | Source key (`copy`, `rename`) |
  | `file_store.dest` | Destination key (`copy`, `rename`) |
  | `file_store.content_size` | `byte_size/1` of content (`write` only) |
  | `file_store.error_type` | Exception module name on error |

  On error tuple returns, span status is set to `:error` with the exception
  message. Raised exceptions are recorded automatically by `with_span`.

  See the documentation for `FileStore.Middleware` for more information.
  """

  @enforce_keys [:__next__]
  defstruct [:__next__, span_prefix: "FileStore.", attributes: %{}]

  @doc "Wrap a store with OpenTelemetry instrumentation."
  def new(store, opts \\ []) do
    opts =
      Keyword.update(opts, :attributes, %{}, fn
        a when is_map(a) -> a
        a -> Map.new(a)
      end)

    struct(__MODULE__, Keyword.put(opts, :__next__, store))
  end

  defimpl FileStore do
    require OpenTelemetry.Tracer, as: Tracer

    def write(store, key, content, opts) do
      Tracer.with_span "#{store.span_prefix}write", %{kind: :client} do
        set_attrs(store, %{
          "code.function" => "write",
          "file_store.key" => key,
          "file_store.content_size" => byte_size(content)
        })

        case FileStore.write(store.__next__, key, content, opts) do
          :ok ->
            :ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def read(store, key) do
      Tracer.with_span "#{store.span_prefix}read", %{kind: :client} do
        set_attrs(store, %{"code.function" => "read", "file_store.key" => key})

        case FileStore.read(store.__next__, key) do
          {:ok, _} = ok ->
            ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def upload(store, source, key) do
      Tracer.with_span "#{store.span_prefix}upload", %{kind: :client} do
        set_attrs(store, %{"code.function" => "upload", "file_store.key" => key})

        case FileStore.upload(store.__next__, source, key) do
          :ok ->
            :ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def download(store, key, destination) do
      Tracer.with_span "#{store.span_prefix}download", %{kind: :client} do
        set_attrs(store, %{"code.function" => "download", "file_store.key" => key})

        case FileStore.download(store.__next__, key, destination) do
          :ok ->
            :ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def stat(store, key) do
      Tracer.with_span "#{store.span_prefix}stat", %{kind: :client} do
        set_attrs(store, %{"code.function" => "stat", "file_store.key" => key})

        case FileStore.stat(store.__next__, key) do
          {:ok, _} = ok ->
            ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def delete(store, key) do
      Tracer.with_span "#{store.span_prefix}delete", %{kind: :client} do
        set_attrs(store, %{"code.function" => "delete", "file_store.key" => key})

        case FileStore.delete(store.__next__, key) do
          :ok ->
            :ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def delete_all(store, opts) do
      Tracer.with_span "#{store.span_prefix}delete_all", %{kind: :client} do
        set_attrs(store, %{"code.function" => "delete_all"})

        case FileStore.delete_all(store.__next__, opts) do
          :ok ->
            :ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def copy(store, src, dest) do
      Tracer.with_span "#{store.span_prefix}copy", %{kind: :client} do
        set_attrs(store, %{
          "code.function" => "copy",
          "file_store.src" => src,
          "file_store.dest" => dest
        })

        case FileStore.copy(store.__next__, src, dest) do
          :ok ->
            :ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def rename(store, src, dest) do
      Tracer.with_span "#{store.span_prefix}rename", %{kind: :client} do
        set_attrs(store, %{
          "code.function" => "rename",
          "file_store.src" => src,
          "file_store.dest" => dest
        })

        case FileStore.rename(store.__next__, src, dest) do
          :ok ->
            :ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def get_signed_url(store, key, opts) do
      Tracer.with_span "#{store.span_prefix}get_signed_url", %{kind: :client} do
        set_attrs(store, %{"code.function" => "get_signed_url", "file_store.key" => key})

        case FileStore.get_signed_url(store.__next__, key, opts) do
          {:ok, _} = ok ->
            ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def put_access_control_list(store, key, acl) do
      Tracer.with_span "#{store.span_prefix}put_access_control_list", %{kind: :client} do
        set_attrs(store, %{
          "code.function" => "put_access_control_list",
          "file_store.key" => key
        })

        case FileStore.put_access_control_list(store.__next__, key, acl) do
          :ok ->
            :ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def set_tags(store, key, tags) do
      Tracer.with_span "#{store.span_prefix}set_tags", %{kind: :client} do
        set_attrs(store, %{"code.function" => "set_tags", "file_store.key" => key})

        case FileStore.set_tags(store.__next__, key, tags) do
          :ok ->
            :ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def get_tags(store, key) do
      Tracer.with_span "#{store.span_prefix}get_tags", %{kind: :client} do
        set_attrs(store, %{"code.function" => "get_tags", "file_store.key" => key})

        case FileStore.get_tags(store.__next__, key) do
          {:ok, _} = ok ->
            ok

          {:error, err} = e ->
            set_error(err)
            e
        end
      end
    end

    def get_public_url(store, key, opts) do
      FileStore.get_public_url(store.__next__, key, opts)
    end

    def list!(store, opts) do
      FileStore.list!(store.__next__, opts)
    end

    defp set_attrs(store, fields) do
      Tracer.set_attributes(Map.merge(store.attributes, fields))
    end

    defp set_error(err) do
      Tracer.set_status(OpenTelemetry.status(:error, Exception.message(err)))
      Tracer.set_attribute("file_store.error_type", inspect(err.__struct__))
    end
  end
end
