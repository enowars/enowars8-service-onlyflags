defmodule Proxy.Application do
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "1080")

    children = [
      {Task.Supervisor, name: Proxy.TaskSupervisor},
      {Task, fn -> Proxy.accept(port) end},
      Proxy.Scheduler,
      {Proxy.UserCache, name: Proxy.UserCache},
      {MyXQL, username: "proxy", hostname: "db", database: "pod", name: :myxql, pool_size: 8}
    ]

    opts = [strategy: :one_for_one, name: Proxy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
