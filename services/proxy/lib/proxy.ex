defmodule Proxy do
  require Logger

  def accept(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true])
    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Proxy.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp auth_methods_type(t) do
    case t do
      0 -> "NO AUTHENTICATION REQUIRED"
      1 -> "GSSAPI"
      2 -> "USERNAME/PASSWORD"
      e -> "UNKNOWN: #{Integer.to_string(e, 16)}"
    end
  end

  defp serve(socket) do
    {:ok, <<5, nmethods>>} = :gen_tcp.recv(socket, 2)
    Logger.info("nmethods: #{nmethods}")
    {:ok, bytes} = :gen_tcp.recv(socket, nmethods)
    Logger.info("Available Auth methods:")

    bytes
    |> :binary.bin_to_list()
    |> Enum.map(&auth_methods_type/1)
    |> Enum.map(&Logger.info(" - #{&1}"))

    :gen_tcp.close(socket)
  end
end
