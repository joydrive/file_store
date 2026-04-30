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

  test "list!/2 includes keys whose path starts with tags_dir name", %{store: store} do
    assert :ok = FileStore.write(store, ".file_store_tags_backup/foo", "data")
    keys = Enum.to_list(FileStore.list!(store))
    assert ".file_store_tags_backup/foo" in keys
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

    test "delete_all/2 removes tag file when prefix names a single key", %{store: store, tmp: tmp} do
      assert :ok = FileStore.write(store, "foo", "")
      assert :ok = FileStore.set_tags(store, "foo", [{"k", "v"}])
      assert :ok = FileStore.delete_all(store, prefix: "foo")
      refute File.exists?(Path.join([tmp, ".file_store_tags", "foo.json"]))
    end

    test "delete_all/2 does not delete tag file of unrelated key when prefix matches .json name",
         %{store: store, tmp: tmp} do
      assert :ok = FileStore.write(store, "foo", "content")
      assert :ok = FileStore.set_tags(store, "foo", [{"k", "v"}])
      assert :ok = FileStore.write(store, "foo.json", "content")
      assert :ok = FileStore.delete_all(store, prefix: "foo.json")
      assert File.exists?(Path.join([tmp, ".file_store_tags", "foo.json"]))
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

  describe "implicit parent directory keys" do
    setup %{store: store} do
      # Writing "foo/bar" causes File.mkdir_p to create /storage/foo/ as a side-effect.
      # "foo" is then a directory entry but was never written as a key.
      assert :ok = FileStore.write(store, "foo/bar", "data")
      :ok
    end

    test "set_tags/3 returns not found for implicit parent directory", %{store: store} do
      assert {:error, %FileStore.NotFound{operation: :set_tags, key: "foo"}} =
               FileStore.set_tags(store, "foo", [{"k", "v"}])
    end

    test "get_tags/2 returns not found for implicit parent directory", %{store: store} do
      assert {:error, %FileStore.NotFound{operation: :get_tags, key: "foo"}} =
               FileStore.get_tags(store, "foo")
    end

    test "rename/2 returns not found for implicit parent directory", %{store: store} do
      assert {:error, %FileStore.NotFound{operation: :rename, src: "foo", dest: "bar"}} =
               FileStore.rename(store, "foo", "bar")
    end

    test "rename/2 does not move implicit parent directory subtree", %{store: store} do
      FileStore.rename(store, "foo", "bar")
      assert {:ok, "data"} = FileStore.read(store, "foo/bar")
    end
  end

  describe "get_tags/2 with corrupt tag files" do
    test "returns invalid argument on invalid JSON", %{store: store, tmp: tmp} do
      assert :ok = FileStore.write(store, "foo", "data")
      tags_path = Path.join([tmp, ".file_store_tags", "foo.json"])
      File.mkdir_p!(Path.dirname(tags_path))
      File.write!(tags_path, "not json")

      assert {:error,
              %FileStore.InvalidArgument{operation: :get_tags, key: "foo", reason: :invalid_tags}} =
               FileStore.get_tags(store, "foo")
    end

    test "returns invalid argument when JSON is not a list", %{store: store, tmp: tmp} do
      assert :ok = FileStore.write(store, "foo", "data")
      tags_path = Path.join([tmp, ".file_store_tags", "foo.json"])
      File.mkdir_p!(Path.dirname(tags_path))
      File.write!(tags_path, ~s({"k": "v"}))

      assert {:error,
              %FileStore.InvalidArgument{operation: :get_tags, key: "foo", reason: :invalid_tags}} =
               FileStore.get_tags(store, "foo")
    end

    test "returns invalid argument when a pair has wrong shape", %{store: store, tmp: tmp} do
      assert :ok = FileStore.write(store, "foo", "data")
      tags_path = Path.join([tmp, ".file_store_tags", "foo.json"])
      File.mkdir_p!(Path.dirname(tags_path))
      File.write!(tags_path, ~s([["k", 123]]))

      assert {:error,
              %FileStore.InvalidArgument{operation: :get_tags, key: "foo", reason: :invalid_tags}} =
               FileStore.get_tags(store, "foo")
    end
  end
end
