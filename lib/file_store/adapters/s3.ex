if Code.ensure_compiled?(ExAws.S3) do
  defmodule FileStore.Adapters.S3 do
    @moduledoc """
    An `FileStore.Adapter` that stores files using Amazon S3.

    ### Requirements

        def deps do
          [
            {:ex_aws_s3, "~> 2.0"},
            {:hackney, ">= 0.0.0"},
            {:sweet_xml, ">= 0.0.0"}
          ]
        end

    ### Configuration

      * `bucket` - The name of your S3 bucket (required).
      * `base_url` - The base URL of your S3 bucket (optional).

    """

    @behaviour FileStore.Adapter

    @impl true
    def get_public_url(store, key, _opts \\ []) do
      store
      |> get_base_url()
      |> URI.merge(key)
      |> URI.to_string()
    end

    @impl true
    def get_signed_url(store, key, opts \\ []) do
      store
      |> get_config()
      |> ExAws.S3.presigned_url(:get, get_bucket(store), key, opts)
    end

    @impl true
    def write(store, key, content) do
      store
      |> get_bucket()
      |> ExAws.S3.put_object(key, content)
      |> request(store)
    end

    @impl true
    def upload(store, source, key) do
      source
      |> ExAws.S3.Upload.stream_file()
      |> ExAws.S3.upload(get_bucket(store), key)
      |> request(store)
    end

    @impl true
    def download(store, key, destionation) do
      store
      |> get_bucket()
      |> ExAws.S3.download_file(key, destionation)
      |> request(store)
    end

    defp request(op, store) do
      case ExAws.request(op, get_overrides(store)) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end

    defp get_base_url(store) do
      Map.get_lazy(store, :base_url, fn ->
        "https://#{get_bucket(store)}.s3-#{get_region(store)}.amazonaws.com"
      end)
    end

    defp get_bucket(store), do: Map.fetch!(store.config, :bucket)
    defp get_region(store), do: store |> get_config() |> Map.fetch!(:region)
    defp get_config(store), do: ExAws.Config.new(:s3, get_overrides(store))
    defp get_overrides(store), do: Map.get(store.config, :ex_aws, [])
  end
end