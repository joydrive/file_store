defmodule FileStore.Adapters.Error do
  @moduledoc false

  defstruct reason: :boom

  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end

  defimpl FileStore do
    def write(store, _key, _content, _opts \\ []), do: {:error, store.reason}
    def read(store, _key), do: {:error, store.reason}
    def upload(store, _source, _key), do: {:error, store.reason}
    def download(store, _key, _destination), do: {:error, store.reason}
    def stat(store, _key), do: {:error, store.reason}
    def delete(store, _key), do: {:error, store.reason}
    def delete_all(store, _opts \\ []), do: {:error, store.reason}
    def copy(store, _src, _dest), do: {:error, store.reason}
    def rename(store, _src, _dest), do: {:error, store.reason}
    def put_access_control_list(store, _key, _acl), do: {:error, store.reason}
    def set_tags(store, _key, _tags), do: {:error, store.reason}
    def get_tags(store, _key), do: {:error, store.reason}
    def get_public_url(_store, key, _opts \\ []), do: key
    def get_signed_url(store, _key, _opts \\ []), do: {:error, store.reason}
    def list!(_store, _opts \\ []), do: []
  end
end
