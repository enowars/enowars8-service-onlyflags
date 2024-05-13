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
      # Logger.info("#{Base.encode16(bytes)}")
      func.(bytes)
    rescue
      e in FunctionClauseError ->
        Logger.warning("#{inspect(e)}")
        throw("protocoll not followed")

      e in MatchError ->
        Logger.warning("#{inspect(e)}")
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

      user_data = handle_rfc1929_auth(socket)
      Logger.info("Auth complete")

      # should always be :connect and {:domain, host}, we never want direct ip access
      {:connect, {:domain, host}, port} = parse_socks_req(socket)

      # don't allow connections to restricted services
      if (case user_data do
            {:regular, restricted_hosts} ->
              Enum.member?(restricted_hosts, host)

            :premium ->
              false
          end) do
        throw_socks_error(
          socket,
          2,
          "not allowed to connect to network #{host}:#{port}"
        )
      end

      Logger.info("Connecting #{:inet.ntoa(cip)}:#{cport} to #{host}:#{port}")

      # TODO: restrict network interface [bind_to_device: "something"]
      case :gen_tcp.connect(host, port, [:binary, packet: :raw], 5) do
        {:ok, conn} ->
          try do
            {:ok, {conaddr, conport}} = :inet.sockname(conn)
            Logger.info("local sock: #{:inet.ntoa(conaddr)}:#{conport}")
          after
            :gen_tcp.close(conn)
          end

        {:error, :econnrefused} ->
          throw_socks_error(socket, 5, "connection refused")

        {:error, :etimedout} ->
          throw_socks_error(socket, 6, "Timed out")
      end
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
      :gen_tcp.send(socket, <<1, 1>>)
      throw("Illegal username")
    end

    data = Proxy.UserCache.get_user(username, passwd)

    if data == nil do
      :gen_tcp.send(socket, <<1, 1>>)
      throw("Auth failure")
    end

    :gen_tcp.send(socket, <<1, 0>>)

    data
  end

  defp parse_socks_req(socket) do
    {
      recv(socket, 2, fn <<5, cmd>> ->
        case cmd do
          1 -> :connect
          # 2 -> :bind
          # 3 -> :udp_assoc
          _ -> throw_socks_error(socket, 0x07, "unknown/unsupported command")
        end
      end),
      recv(socket, 2, fn <<0, atyp>> ->
        case atyp do
          # 1 ->
          #  {:ipv4, recv(socket, 4, &(for(<<group <- &1>>, do: group) |> List.to_tuple()))}

          3 ->
            {:domain,
             recv(socket, 1, fn <<dlength>> ->
               recv(socket, dlength, & &1)
             end)}

          # 4 ->
          #  {:ipv6, recv(socket, 16, &(for(<<group::16 <- &1>>, do: group) |> List.to_tuple()))}

          _ ->
            throw_socks_error(socket, 0x08, "unknown/unsupported addr type")
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
