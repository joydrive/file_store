{:ok, _} = Application.ensure_all_started(:hackney)
{:ok, _} = Application.ensure_all_started(:telemetry)

Application.stop(:opentelemetry)
Application.put_env(:opentelemetry, :processors, [{:otel_simple_processor, %{}}])
{:ok, _} = Application.ensure_all_started(:opentelemetry)
Logger.put_application_level(:opentelemetry, :warning)
Logger.put_application_level(:telemetry, :warning)

ExUnit.start()
