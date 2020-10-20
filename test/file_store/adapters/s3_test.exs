defmodule FileStore.Adapters.S3Test do
  use FileStore.AdapterCase
  alias FileStore.Adapters.S3

  @region "us-east-1"
  @bucket "filestore"
  @url "http://filestore.localhost:4569/foo"

  setup do
    {:ok, _} = Application.ensure_all_started(:hackney)
    {:ok, _} = ensure_bucket_exists()
    {:ok, store: S3.new(bucket: @bucket)}
  end

  test "get_public_url/2", %{store: store} do
    assert FileStore.get_public_url(store, "foo") == @url
  end

  test "get_signed_url/2", %{store: store} do
    assert {:ok, url} = FileStore.get_signed_url(store, "foo")
    assert omit_query(url) == @url
    assert get_query(url, "X-Amz-Expires") == "3600"
  end

  test "get_signed_url/2 with custom expiration", %{store: store} do
    assert {:ok, url} = FileStore.get_signed_url(store, "foo", expires_in: 4000)
    assert omit_query(url) == @url
    assert get_query(url, "X-Amz-Expires") == "4000"
  end

  test "list/2 respects trailing slashes", %{store: store} do
    assert :ok = FileStore.write(store, "bar", "")
    assert :ok = FileStore.write(store, "foo", "")
    assert :ok = FileStore.write(store, "foo/bar", "")

    keys = Enum.to_list(FileStore.list!(store, prefix: "foo"))
    refute "bar" in keys
    assert "foo" in keys
    assert "foo/bar" in keys

    keys = Enum.to_list(FileStore.list!(store, prefix: "foo/"))
    refute "bar" in keys
    refute "foo" in keys
    assert "foo/bar" in keys
  end

  defp get_query(url, param) do
    url
    |> URI.parse()
    |> Map.fetch!(:query)
    |> URI.decode_query()
    |> Map.fetch!(param)
  end

  defp omit_query(url) do
    url
    |> URI.parse()
    |> Map.put(:query, nil)
    |> URI.to_string()
  end

  defp ensure_bucket_exists do
    @bucket
    |> ExAws.S3.head_bucket()
    |> ExAws.request()
    |> case do
      {:ok, resp} -> {:ok, resp}
      {:error, _} -> create_bucket()
    end
  end

  defp create_bucket do
    @bucket
    |> ExAws.S3.put_bucket(@region)
    |> ExAws.request()
  end
end
