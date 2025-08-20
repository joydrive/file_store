defmodule FileStore.Middleware.Errors do
  @moduledoc """
  By default, each adapter will return errors in a different format. This
  middleware attempts to make the errors returned by this library a little
  more useful by wrapping them in exception structs:

    * `FileStore.Error`
    * `FileStore.UploadError`
    * `FileStore.DownloadError`
    * `FileStore.CopyError`
    * `FileStore.RenameError`
    * `FileStore.PutAccessControlListError`

  Each of these structs contain `reason` field, where you'll find the original
  error that was returned by the underlying adapter.

  One nice feature of this middleware is that it makes it easy to raise:

      store
      |> FileStore.Middleware.Errors.new()
      |> FileStore.read("example.jpg")
      |> case do
        {:ok, data} -> data
        {:error, error} -> raise error
      end

  See the documentation for `FileStore.Middleware` for more information.
  """

  @enforce_keys [:__next__]
  defstruct [:__next__]

  def new(store) do
    %__MODULE__{__next__: store}
  end

  defimpl FileStore do
    alias FileStore.Error
    alias FileStore.UploadError
    alias FileStore.DownloadError
    alias FileStore.RenameError
    alias FileStore.CopyError
    alias FileStore.PutAccessControlListError
    alias FileStore.SetTagsError
    alias FileStore.GetTagsError

    def stat(store, key) do
      store.__next__
      |> FileStore.stat(key)
      |> wrap(action: "read stats for key", key: key)
    end

    def write(store, key, content, opts) do
      store.__next__
      |> FileStore.write(key, content, opts)
      |> wrap(action: "write to key", key: key)
    end

    def read(store, key) do
      store.__next__
      |> FileStore.read(key)
      |> wrap(action: "read key", key: key)
    end

    def copy(store, src, dest) do
      store.__next__
      |> FileStore.copy(src, dest)
      |> wrap(CopyError, src: src, dest: dest)
    end

    def rename(store, src, dest) do
      store.__next__
      |> FileStore.rename(src, dest)
      |> wrap(RenameError, src: src, dest: dest)
    end

    def put_access_control_list(store, key, acl) do
      store.__next__
      |> FileStore.put_access_control_list(key, acl)
      |> wrap(PutAccessControlListError, key: key, acl: acl)
    end

    def set_tags(store, key, tags) do
      store.__next__
      |> FileStore.set_tags(key, tags)
      |> wrap(SetTagsError)
    end

    def get_tags(store, key) do
      store.__next__
      |> FileStore.get_tags(key)
      |> wrap(GetTagsError)
    end

    def upload(store, path, key) do
      store.__next__
      |> FileStore.upload(path, key)
      |> wrap(UploadError, path: path, key: key)
    end

    def download(store, key, path) do
      store.__next__
      |> FileStore.download(key, path)
      |> wrap(DownloadError, path: path, key: key)
    end

    def delete(store, key) do
      store.__next__
      |> FileStore.delete(key)
      |> wrap(action: "delete key", key: key)
    end

    def delete_all(store, opts) do
      prefix = opts[:prefix]

      action =
        if prefix,
          do: "delete keys matching prefix",
          else: "delete all keys"

      store.__next__
      |> FileStore.delete_all(opts)
      |> wrap(action: action, key: prefix)
    end

    def get_public_url(store, key, opts) do
      FileStore.get_public_url(store.__next__, key, opts)
    end

    def get_signed_url(store, key, opts) do
      store.__next__
      |> FileStore.get_signed_url(key, opts)
      |> wrap(action: "generate signed URL for key", key: key)
    end

    def list!(store, opts) do
      FileStore.list!(store.__next__, opts)
    end

    defp wrap(result, error \\ Error, opts)

    defp wrap({:error, reason}, kind, opts) do
      {:error, struct(kind, Keyword.put(opts, :reason, reason))}
    end

    defp wrap(other, _, _), do: other
  end
end
