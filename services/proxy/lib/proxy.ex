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

  defp recv(socket, length, func) do
    try do
      {:ok, bytes} = :gen_tcp.recv(socket, length)
      func.(bytes)
    rescue
      e in FunctionClauseError ->
        Logger.warning("#{e}")
        throw("protocoll not followed")

      e in MatchError ->
        Logger.warning("#{e}")
        throw("protocoll not followed")
    end
  end

  defp serve(socket) do
    {:ok, {cip, cport}} = :inet.peername(socket)

    try do
      available =
        recv(socket, 2, fn <<5, nmethods>> -> recv(socket, nmethods, &:binary.bin_to_list/1) end)

      if not Enum.member?(available, 0x2) do
        :gen_tcp.send(socket, <<5, 0xFF>>)
        throw("No acceptable Authentication method found")
      end

      handle_rfc1929_auth(socket)
      Logger.info("Auth complete")

      {cmd, addr, port} = parse_socks_req(socket)

      Logger.info(
        "Connecting #{:inet.ntoa(cip)}:#{cport} to #{:inet.ntoa(elem(addr, 1))}:#{port}"
      )
    catch
      e ->
        Logger.warning("Disconnected from client(#{:inet.ntoa(cip)}:#{cport}): #{e}")
    after
      :gen_tcp.close(socket)
    end
  end

  defp handle_rfc1929_auth(socket) do
    :gen_tcp.send(socket, <<5, 0x2>>)
    username = recv(socket, 2, fn <<1, nusername>> -> recv(socket, nusername, & &1) end)
    passwd = recv(socket, 1, fn <<npasswd>> -> recv(socket, npasswd, & &1) end)

    if not ([username, passwd] |> Enum.map(&String.valid?/1) |> Enum.all?()) do
      :gen_tcp.send(socket, <<5, 1>>)
      throw("Illegal username")
    end

    # TODO: Do auth correctly
    if {"unreal", "hunter1"} !== {username, passwd} do
      :gen_tcp.send(socket, <<5, 1>>)
      throw("Auth failure")
    end

    :gen_tcp.send(socket, <<5, 0>>)
  end

  defp parse_socks_req(socket) do
    {
      recv(socket, 2, fn <<5, cmd>> ->
        case cmd do
          1 -> :connect
          2 -> :bind
          3 -> :udp_assoc
          _ -> throw_socks_error(socket, 0x07, "unknown/unsupported Command")
        end
      end),
      recv(socket, 2, fn <<0, atyp>> ->
        case atyp do
          1 ->
            {:ipv4, recv(socket, 4, &(for(<<group <- &1>>, do: group) |> List.to_tuple()))}

          3 ->
            {:domain, recv(socket, 1, fn dlength -> recv(socket, dlength, & &1) end)}

          4 ->
            {:ipv6, recv(socket, 16, &(for(<<group::16 <- &1>>, do: group) |> List.to_tuple()))}

          _ ->
            throw_socks_error(socket, 0x08, "fake addr type")
        end
      end),
      recv(socket, 2, &:binary.decode_unsigned/1)
    }
  end

  defp throw_socks_error(socket, id, msg) do
    :gen_tcp.send(socket, <<5, id, 0, 1, 0, 0, 0, 0, 0, 0>>)
    throw(msg)
  end
end
