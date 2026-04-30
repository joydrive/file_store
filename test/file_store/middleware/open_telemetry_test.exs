defmodule FileStore.Middleware.OpenTelemetryTest do
  use FileStore.AdapterCase

  require Record

  Record.defrecord(:span, Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl"))

  alias FileStore.Adapters.Memory
  alias FileStore.Middleware.OpenTelemetry

  @config [base_url: "http://localhost:4000"]

  setup do
    start_supervised!(Memory)
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())
    store = Memory.new(@config) |> OpenTelemetry.new()
    {:ok, store: store}
  end

  test "creates a span for write with correct name and kind", %{store: store} do
    assert :ok = FileStore.write(store, "foo", "bar")

    assert_receive {:span, span}
    assert span(span, :name) == "FileStore.write"
    assert span(span, :kind) == :client
  end

  test "span attributes include key and content_size for write", %{store: store} do
    assert :ok = FileStore.write(store, "foo", "bar")

    assert_receive {:span, span}
    attrs = attrs_map(span)
    assert attrs["file_store.key"] == "foo"
    assert attrs["file_store.content_size"] == 3
    assert attrs["code.function"] == "write"
  end

  test "span status is error on failed read", %{store: store} do
    assert {:error, _} = FileStore.read(store, "missing")

    assert_receive {:span, span}
    assert span(span, :name) == "FileStore.read"
    assert {_, :error, _} = span(span, :status)
    attrs = attrs_map(span)
    assert attrs["file_store.error_type"] == "FileStore.NotFound"
  end

  test "creates span for stat", %{store: store} do
    assert :ok = FileStore.write(store, "foo", "bar")
    # consume write span
    assert_receive {:span, _write_span}

    assert {:ok, _} = FileStore.stat(store, "foo")
    assert_receive {:span, span}
    assert span(span, :name) == "FileStore.stat"
  end

  test "copy span includes src and dest attributes", %{store: store} do
    assert :ok = FileStore.write(store, "src", "data")
    assert_receive {:span, _}

    assert :ok = FileStore.copy(store, "src", "dst")
    assert_receive {:span, span}
    assert span(span, :name) == "FileStore.copy"
    attrs = attrs_map(span)
    assert attrs["file_store.src"] == "src"
    assert attrs["file_store.dest"] == "dst"
  end

  test "rename span includes src and dest attributes", %{store: store} do
    assert :ok = FileStore.write(store, "old", "data")
    assert_receive {:span, _}

    assert :ok = FileStore.rename(store, "old", "new")
    assert_receive {:span, span}
    assert span(span, :name) == "FileStore.rename"
    attrs = attrs_map(span)
    assert attrs["file_store.src"] == "old"
    assert attrs["file_store.dest"] == "new"
  end

  test "static attributes appear on all spans", %{store: _store} do
    store =
      Memory.new(@config)
      |> OpenTelemetry.new(attributes: %{"service.name" => "files"})

    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    assert :ok = FileStore.write(store, "x", "y")
    assert_receive {:span, span}
    assert attrs_map(span)["service.name"] == "files"
  end

  test "custom span prefix is applied", %{store: _store} do
    store =
      Memory.new(@config)
      |> OpenTelemetry.new(span_prefix: "my_app.storage.")

    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())

    assert :ok = FileStore.write(store, "x", "y")
    assert_receive {:span, span}
    assert span(span, :name) == "my_app.storage.write"
  end

  test "get_public_url does not create a span", %{store: store} do
    assert :ok = FileStore.write(store, "foo", "bar")
    assert_receive {:span, _write_span}

    FileStore.get_public_url(store, "foo")
    refute_receive {:span, _}, 100
  end

  defp attrs_map(span) do
    span
    |> span(:attributes)
    |> :otel_attributes.map()
  end
end
