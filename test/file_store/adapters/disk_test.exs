defmodule FileStore.Adapters.DiskTest do
  use FileStore.AdapterCase

  alias FileStore.Adapters.Disk

  @url "http://localhost:4000/foo"

  setup %{tmp: tmp} do
    {:ok, store: Disk.new(storage_path: tmp, base_url: "http://localhost:4000")}
  end

  test "get_public_url/3 with query params", %{store: store} do
    opts = [content_type: "text/plain", disposition: "attachment"]
    url = FileStore.get_public_url(store, "foo", opts)
    assert omit_query(url) == @url
    assert get_query(url, "content_type") == "text/plain"
    assert get_query(url, "disposition") == "attachment"
  end

  test "get_signed_url/3 with query params", %{store: store} do
    opts = [content_type: "text/plain", disposition: "attachment"]
    assert {:ok, url} = FileStore.get_signed_url(store, "foo", opts)
    assert omit_query(url) == @url
    assert get_query(url, "content_type") == "text/plain"
    assert get_query(url, "disposition") == "attachment"
  end

  test "tags_dir option stores tag files in custom directory", %{tmp: tmp} do
    store = Disk.new(storage_path: tmp, base_url: "http://localhost:4000", tags_dir: "my_tags")
    assert :ok = FileStore.write(store, "foo", "bar")
    assert :ok = FileStore.set_tags(store, "foo", [{"k", "v"}])
    assert File.exists?(Path.join([tmp, "my_tags", "foo.json"]))
    assert {:ok, [{"k", "v"}]} = FileStore.get_tags(store, "foo")
  end

  describe "tag lifecycle" do
    test "write/4 clears stale tags on overwrite", %{store: store} do
      assert :ok = FileStore.write(store, "foo", "v1")
      assert :ok = FileStore.set_tags(store, "foo", [{"k", "v"}])
      assert :ok = FileStore.write(store, "foo", "v2")
      assert {:ok, []} = FileStore.get_tags(store, "foo")
    end

    test "delete/2 removes tag file", %{store: store, tmp: tmp} do
      assert :ok = FileStore.write(store, "foo", "bar")
      assert :ok = FileStore.set_tags(store, "foo", [{"k", "v"}])
      assert :ok = FileStore.delete(store, "foo")
      refute File.exists?(Path.join([tmp, ".file_store_tags", "foo.json"]))
    end

    test "delete_all/2 removes tag files under prefix", %{store: store, tmp: tmp} do
      assert :ok = FileStore.write(store, "dir/a", "")
      assert :ok = FileStore.set_tags(store, "dir/a", [{"k", "v"}])
      assert :ok = FileStore.write(store, "other", "")
      assert :ok = FileStore.set_tags(store, "other", [{"k", "v"}])
      assert :ok = FileStore.delete_all(store, prefix: "dir")
      refute File.exists?(Path.join([tmp, ".file_store_tags", "dir", "a.json"]))
      assert File.exists?(Path.join([tmp, ".file_store_tags", "other.json"]))
    end

    test "delete_all/2 with no prefix removes all tag files", %{store: store, tmp: tmp} do
      assert :ok = FileStore.write(store, "foo", "")
      assert :ok = FileStore.set_tags(store, "foo", [{"k", "v"}])
      assert :ok = FileStore.delete_all(store)
      refute File.exists?(Path.join([tmp, ".file_store_tags"]))
    end

    test "copy/3 copies tags from source to destination", %{store: store} do
      tags = [{"env", "prod"}]
      assert :ok = FileStore.write(store, "src", "data")
      assert :ok = FileStore.set_tags(store, "src", tags)
      assert :ok = FileStore.copy(store, "src", "dest")
      assert {:ok, ^tags} = FileStore.get_tags(store, "dest")
      assert {:ok, ^tags} = FileStore.get_tags(store, "src")
    end

    test "copy/3 clears stale dest tags when source has none", %{store: store} do
      assert :ok = FileStore.write(store, "src", "data")
      assert :ok = FileStore.write(store, "dest", "old")
      assert :ok = FileStore.set_tags(store, "dest", [{"k", "v"}])
      assert :ok = FileStore.copy(store, "src", "dest")
      assert {:ok, []} = FileStore.get_tags(store, "dest")
    end

    test "rename/3 moves tags to destination", %{store: store} do
      tags = [{"env", "prod"}]
      assert :ok = FileStore.write(store, "src", "data")
      assert :ok = FileStore.set_tags(store, "src", tags)
      assert :ok = FileStore.rename(store, "src", "dest")
      assert {:ok, ^tags} = FileStore.get_tags(store, "dest")
    end

    test "rename/3 clears stale dest tags when source has none", %{store: store} do
      assert :ok = FileStore.write(store, "src", "data")
      assert :ok = FileStore.write(store, "dest", "old")
      assert :ok = FileStore.set_tags(store, "dest", [{"k", "v"}])
      assert :ok = FileStore.rename(store, "src", "dest")
      assert {:ok, []} = FileStore.get_tags(store, "dest")
    end
  end
end
