import Config

config :proxy, Proxy.Scheduler,
  jobs: [
    {{:extended, "*/5"}, {Proxy.Cleaner, :cleanup, []}}
  ]
