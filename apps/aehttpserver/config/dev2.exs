use Mix.Config

config :aehttpserver, Aehttpserver.Web.Endpoint,
  http: [port: 4002],
  debug_errors: true,
  code_reloader: false,
  check_origin: false,
  server: true,
  watchers: []

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
