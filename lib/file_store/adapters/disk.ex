defmodule FileStore.Adapters.Disk do
  @moduledoc """
  Stores files on the local disk. This is primarily intended for development.

  ### Configuration

    * `storage_path` - The path on disk where files are
      stored. This option is required.

    * `base_url` - The base URL that should be used for
       generating URLs to your files.

    * `tags_dir` - The directory name (relative to `storage_path`) used
      to store tag files. Defaults to `".file_store_tags"`.

  ### Example

      iex> store = FileStore.Adapters.Disk.new(
      ...>   storage_path: "/path/to/store/files",
      ...>   base_url: "http://example.com/files/"
      ...> )
      %FileStore.Adapters.Disk{...}

      iex> FileStore.write(store, "foo", "hello world")
      :ok

      iex> FileStore.read(store, "foo")
      {:ok, "hello world"}

  """

  @enforce_keys [:storage_path, :base_url]
  defstruct [:storage_path, :base_url, tags_dir: ".file_store_tags"]

  @doc "Create a new disk adapter"
  @spec new(keyword) :: FileStore.t()
  def new(opts) do
    if is_nil(opts[:storage_path]) do
      raise "missing configuration: :storage_path"
    end

    if is_nil(opts[:base_url]) do
      raise "missing configuration: :base_url"
    end

    struct(__MODULE__, opts)
  end

  @doc "Get an the path for a given key."
  @spec join(FileStore.t(), binary) :: Path.t()
  def join(store, key) do
    Path.join(store.storage_path, key)
  end

  defimpl FileStore do
    alias FileStore.Stat
    alias FileStore.Utils
    alias FileStore.Adapters.Disk

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
      with path <- Disk.join(store, key),
           {:ok, stat} <- File.stat(path),
           {:ok, etag} <- FileStore.Stat.checksum_file(path) do
        {
          :ok,
          %Stat{
            key: key,
            size: stat.size,
            etag: etag,
            type: "application/octet-stream"
          }
        }
      end
    end

    def delete(store, key) do
      case File.rm(Disk.join(store, key)) do
        {:error, reason} when reason not in [:enoent, :enotdir] ->
          {:error, reason}

        _ ->
          _ = File.rm(tags_path(store, key))
          :ok
      end
    end

    def delete_all(store, opts) do
      prefix = Keyword.get(opts, :prefix, "")
      tags_subtree = Path.join([store.storage_path, store.tags_dir, prefix])

      with {:ok, _} <- store.storage_path |> Path.join(prefix) |> File.rm_rf(),
           {:ok, _} <-
             (if File.dir?(tags_subtree), do: File.rm_rf(tags_subtree), else: {:ok, []}),
           {:ok, _} <- File.rm_rf(tags_subtree <> ".json") do
        :ok
      else
        {:error, reason, _file} -> {:error, reason}
      end
    end

    def write(store, key, content, _opts \\ []) do
      with {:ok, path} <- expand(store, key) do
        _ = File.rm(tags_path(store, key))
        File.write(path, content)
      end
    end

    def read(store, key) do
      store |> Disk.join(key) |> File.read()
    end

    def copy(store, src, dest) do
      with {:ok, src_path} <- expand(store, src),
           {:ok, dest_path} <- expand(store, dest),
           {:ok, _} <- File.copy(src_path, dest_path),
           do: copy_tags(store, src, dest)
    end

    defp copy_tags(store, src, dest) do
      src_tags = tags_path(store, src)
      dest_tags = tags_path(store, dest)

      if File.exists?(src_tags) do
        with :ok <- File.mkdir_p(Path.dirname(dest_tags)),
             {:ok, _} <- File.copy(src_tags, dest_tags),
             do: :ok
      else
        _ = File.rm(dest_tags)
        :ok
      end
    end

    def rename(store, src, dest) do
      src_path = Disk.join(store, src)

      if File.regular?(src_path) do
        with {:ok, dest_path} <- expand(store, dest),
             :ok <- File.rename(src_path, dest_path),
             do: rename_tags(store, src, dest)
      else
        {:error, :enoent}
      end
    end

    defp rename_tags(store, src, dest) do
      src_tags = tags_path(store, src)
      dest_tags = tags_path(store, dest)

      if File.exists?(src_tags) do
        with :ok <- File.mkdir_p(Path.dirname(dest_tags)),
             do: File.rename(src_tags, dest_tags)
      else
        _ = File.rm(dest_tags)
        :ok
      end
    end

    def put_access_control_list(_store, _key, _acl), do: :ok

    def set_tags(store, key, tags) do
      path = Disk.join(store, key)

      if File.regular?(path) do
        tags_path = tags_path(store, key)
        tags_dir = Path.dirname(tags_path)

        with :ok <- File.mkdir_p(tags_dir) do
          File.write(tags_path, Jason.encode!(Enum.map(tags, &Tuple.to_list/1)))
        end
      else
        {:error, :enoent}
      end
    end

    def get_tags(store, key) do
      path = Disk.join(store, key)

      if File.regular?(path) do
        case File.read(tags_path(store, key)) do
          {:ok, data} -> decode_tags(data)
          {:error, :enoent} -> {:ok, []}
          {:error, reason} -> {:error, reason}
        end
      else
        {:error, :enoent}
      end
    end

    def upload(store, source, key) do
      with {:ok, dest} <- expand(store, key),
           {:ok, _} <- File.copy(source, dest),
           do: :ok
    end

    def download(store, key, dest) do
      with {:ok, source} <- expand(store, key),
           {:ok, _} <- File.copy(source, dest),
           do: :ok
    end

    def list!(store, opts) do
      prefix = Keyword.get(opts, :prefix, "")
      tags_dir = Path.join(store.storage_path, store.tags_dir)

      store.storage_path
      |> Path.join(prefix)
      |> Path.join("**/*")
      |> Path.wildcard(match_dot: true)
      |> Stream.reject(&File.dir?/1)
      |> Stream.reject(&String.starts_with?(&1, tags_dir <> "/"))
      |> Stream.map(&Path.relative_to(&1, store.storage_path))
    end

    defp tags_path(store, key) do
      Path.join([store.storage_path, store.tags_dir, key <> ".json"])
    end

    defp decode_tags(data) do
      case Jason.decode(data) do
        {:ok, pairs} when is_list(pairs) -> decode_tag_pairs(pairs)
        _ -> {:error, :invalid_tags}
      end
    end

    defp decode_tag_pairs(pairs) do
      Enum.reduce_while(pairs, {:ok, []}, fn
        [k, v], {:ok, acc} when is_binary(k) and is_binary(v) ->
          {:cont, {:ok, [{k, v} | acc]}}

        _, _ ->
          {:halt, {:error, :invalid_tags}}
      end)
      |> case do
        {:ok, tags} -> {:ok, Enum.reverse(tags)}
        error -> error
      end
    end

    defp expand(store, key) do
      with path <- Disk.join(store, key),
           dir <- Path.dirname(path),
           :ok <- File.mkdir_p(dir),
           do: {:ok, path}
    end
  end
end
