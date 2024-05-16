import Config

config :proxy, Proxy.Scheduler,
  jobs: [
    {{:extended, "*/5"}, {Proxy.UserCache, :update_user_cache, []}}
  ]
