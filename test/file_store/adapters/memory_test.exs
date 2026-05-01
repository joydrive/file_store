defmodule FileStore.Adapters.MemoryTest do
  use FileStore.AdapterCase

  alias FileStore.Adapters.Memory

  @url "http://localhost:4000/foo"

  setup do
    start_supervised!(Memory)
    {:ok, store: Memory.new(base_url: "http://localhost:4000")}
  end

  test "new/1 raises when base_url is missing" do
    assert_raise RuntimeError, "missing configuration: :base_url", fn ->
      Memory.new([])
    end
  end

  test "stop/3 stops the agent" do
    {:ok, pid} = Agent.start_link(fn -> %{} end)
    store = Memory.new(base_url: "http://localhost:4000", name: pid)
    assert :ok = Memory.stop(store)
    refute Process.alive?(pid)
  end

  test "set_tags/3 returns not found for missing key", %{store: store} do
    assert {:error, %FileStore.NotFound{operation: :set_tags}} =
             FileStore.set_tags(store, "nonexistent", [{"k", "v"}])
  end

  test "get_tags/2 returns not found for missing key", %{store: store} do
    assert {:error, %FileStore.NotFound{operation: :get_tags}} =
             FileStore.get_tags(store, "nonexistent")
  end

  test "download/3 returns not found for missing key", %{store: store, tmp: tmp} do
    assert {:error, %FileStore.NotFound{operation: :download}} =
             FileStore.download(store, "nonexistent", Path.join(tmp, "dest"))
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

  test "set_tags/3 and get_tags/2", %{store: store} do
    tags = %{"tag1" => "value1", "tag2" => "value2"}

    assert :ok = FileStore.write(store, "foo", "content")
    assert :ok = FileStore.set_tags(store, "foo", tags)
    assert {:ok, ^tags} = FileStore.get_tags(store, "foo")
  end
end
