{:ok, _} = Application.ensure_all_started(:hackney)
{:ok, _} = Application.ensure_all_started(:telemetry)

Application.stop(:opentelemetry)
Application.put_env(:opentelemetry, :processors, [{:otel_simple_processor, %{}}])
{:ok, _} = Application.ensure_all_started(:opentelemetry)

ExUnit.start()
