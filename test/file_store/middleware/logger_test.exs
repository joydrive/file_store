defmodule FileStore.Middleware.LoggerTest do
  use FileStore.AdapterCase
  import ExUnit.CaptureLog
  require Logger

  alias FileStore.Adapters.Memory

  @config [base_url: "http://localhost:4000"]

  setup :silence_logger

  setup do
    start_supervised!(Memory)
    store = Memory.new(@config)
    store = FileStore.Middleware.Logger.new(store)
    {:ok, store: store}
  end

  test "logs a successful write", %{store: store} do
    Logger.configure(level: :debug)
    out = capture_log(fn -> FileStore.write(store, "foo", "bar") end)
    assert out =~ ~r/WRITE OK key="foo"/
  end

  test "logs a failed read", %{store: store} do
    Logger.configure(level: :debug)
    out = capture_log(fn -> FileStore.read(store, "none") end)
    assert out =~ ~r/READ ERROR key="none"/
    assert out =~ "FileStore.NotFound"
  end

  defp silence_logger(_) do
    Logger.configure(level: :none)

    on_exit(fn ->
      Logger.configure(level: :debug)
    end)
  end
end
