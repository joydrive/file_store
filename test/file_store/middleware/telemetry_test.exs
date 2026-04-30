defmodule FileStore.Middleware.TelemetryTest do
  use FileStore.AdapterCase

  alias FileStore.Adapters.Memory
  alias FileStore.Middleware.Telemetry

  @config [base_url: "http://localhost:4000"]

  @ops [
    :write,
    :read,
    :upload,
    :download,
    :stat,
    :delete,
    :delete_all,
    :copy,
    :rename,
    :get_signed_url,
    :put_access_control_list,
    :set_tags,
    :get_tags
  ]

  setup do
    start_supervised!(Memory)
    store = Memory.new(@config) |> Telemetry.new()

    events =
      for op <- @ops, evt <- [:start, :stop, :exception],
          do: [:file_store, op, evt]

    pid = self()
    handler_id = "test-telemetry-#{inspect(pid)}"

    :telemetry.attach_many(
      handler_id,
      events,
      fn name, measurements, metadata, _ -> send(pid, {:telemetry, name, measurements, metadata}) end,
      %{}
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, store: store}
  end

  test "emits start and stop events on successful write", %{store: store} do
    assert :ok = FileStore.write(store, "foo", "bar")

    assert_receive {:telemetry, [:file_store, :write, :start], %{monotonic_time: _}, meta}
    assert meta.operation == :write
    assert meta.key == "foo"
    assert meta.content_size == 3

    assert_receive {:telemetry, [:file_store, :write, :stop], %{duration: _}, meta}
    assert meta.result == :ok
  end

  test "emits stop event with error on failed read", %{store: store} do
    assert {:error, _} = FileStore.read(store, "missing")

    assert_receive {:telemetry, [:file_store, :read, :start], _, _}

    assert_receive {:telemetry, [:file_store, :read, :stop], _, meta}
    assert meta.result == :error
    assert %FileStore.NotFound{} = meta.error
  end

  test "propagates static metadata on all events", %{store: _store} do
    store =
      Memory.new(@config)
      |> Telemetry.new(metadata: %{tenant: "acme"})

    assert :ok = FileStore.write(store, "x", "y")

    assert_receive {:telemetry, [:file_store, :write, :start], _, meta}
    assert meta.tenant == "acme"

    assert_receive {:telemetry, [:file_store, :write, :stop], _, meta}
    assert meta.tenant == "acme"
  end

  test "supports custom event prefix", %{store: _store} do
    store =
      Memory.new(@config)
      |> Telemetry.new(event_prefix: [:my_app, :storage])

    pid = self()
    handler_id = "test-prefix-#{inspect(pid)}"

    :telemetry.attach_many(
      handler_id,
      [[:my_app, :storage, :write, :start], [:my_app, :storage, :write, :stop]],
      fn name, meas, meta, _ -> send(pid, {:telemetry, name, meas, meta}) end,
      %{}
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    assert :ok = FileStore.write(store, "a", "b")
    assert_receive {:telemetry, [:my_app, :storage, :write, :start], _, _}
    assert_receive {:telemetry, [:my_app, :storage, :write, :stop], _, _}
  end

  test "does not emit events for get_public_url", %{store: store} do
    pid = self()
    handler_id = "test-no-url-#{inspect(pid)}"

    :telemetry.attach_many(
      handler_id,
      [[:file_store, :get_public_url, :start]],
      fn name, meas, meta, _ -> send(pid, {:telemetry, name, meas, meta}) end,
      %{}
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    FileStore.write(store, "foo", "bar")
    FileStore.get_public_url(store, "foo")

    refute_receive {:telemetry, [:file_store, :get_public_url, :start], _, _}
  end

  test "copy emits src and dest in metadata", %{store: store} do
    assert :ok = FileStore.write(store, "src", "data")
    assert :ok = FileStore.copy(store, "src", "dst")

    assert_receive {:telemetry, [:file_store, :copy, :start], _, meta}
    assert meta.src == "src"
    assert meta.dest == "dst"
  end

  test "rename emits src and dest in metadata", %{store: store} do
    assert :ok = FileStore.write(store, "old", "data")
    assert :ok = FileStore.rename(store, "old", "new")

    assert_receive {:telemetry, [:file_store, :rename, :start], _, meta}
    assert meta.src == "old"
    assert meta.dest == "new"
  end
end
