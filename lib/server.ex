defmodule Client do
  @enforce_keys [:id]
  defstruct id: nil, pos: %{:x => 0, :y => 0}

  def modify_pos(client, dx, dy) do
    %{client | pos: %{x: client.pos.x + dx, y: client.pos.y + dy}}
  end

  def modify_pos(client, dir) do
    new_pos =
      case dir do
        :left -> %{client.pos | x: client.pos.x - 1}
        :right -> %{client.pos | x: client.pos.x + 1}
        :up -> %{client.pos | y: client.pos.y - 1}
        :down -> %{client.pos | y: client.pos.y + 1}
        _ -> client.pos
      end

    %{client | pos: new_pos}
  end
end

defmodule UdpServer.Server do
  use GenServer
  alias UdpServer.Utils, as: Utils

  # We need a factory method to create our server process
  # it takes a single parameter `port` which defaults to `2052`
  # This runs in the caller's context
  def start_link(server) do
    System.no_halt(true)
    # Start 'er up
    GenServer.start_link(__MODULE__, server)
  end

  # Initialization that runs in the server context (inside the server process right after it boots)
  def init(%{addr: _addr, port: port}) do
    state = UdpServer.Container.get()

    if state.socket != nil do
      IO.puts("Server restarted, state restored")
    end

    {:ok, socket} =
      :gen_udp.open(port, [:binary, active: true, multicast_loop: false, reuseaddr: true])

    # TODO: Move to multicast
    # :inet.setopts(socket, [ip: addr, add_membership: {addr, {0,0,0,0}}, multicast_ttl: 4])

    {:ok, %{state | :socket => socket}}
  end

  # Store the state in the container upon server termination
  def terminate(_reason, state) do
    UdpServer.Container.update(state)
  end

  # define a callback handler for when gen_udp sends us a UDP packet
  def handle_info({:udp, _socket, _address, port, data}, state) do
    {:noreply, state} = handle_packet({data, port}, state)
    UdpServer.Container.update(state)
    {:noreply, state}
  end

  # Ignore everything else
  def handle_info({_, _socket}, state) do
    {:noreply, state}
  end

  # client connects
  defp handle_packet({"connect", port}, state) do
    IO.puts("#{port} connected")

    new_client = %Client{id: Utils.gen_id(state.clients)}
    updated_clients = Map.put(state.clients, port, new_client)

    if state.clients != %{} do
      other_player_positions =
        Map.to_list(state.clients)
        |> Enum.reduce("c:", fn {client_port, %{id: id, pos: pos}}, acc ->
          if client_port != port, do: acc <> "#{id},#{pos.x},#{pos.y};", else: acc
        end)
        |> String.slice(0..-2)

      send_to_client(state.socket, port, other_player_positions)
    end

    {:noreply, %{state | :clients => updated_clients}}
  end

  # client disconnects
  defp handle_packet({"disconnect", port}, state) do
    IO.puts("#{port} disconnected")

    %{id: id} = Map.get(state.clients, port)
    broadcast("d:#{id}", port, state)

    updated_clients = Map.delete(state.clients, port)
    {:noreply, %{state | :clients => updated_clients}}
  end

  # pattern match to handle all other messages
  defp handle_packet({data, port}, state) do
    if Map.has_key?(state.clients, port) do
      client = state.clients[port]

      updated_state =
        case String.trim(data) do
          "ml" -> update_client_pos(Client.modify_pos(client, :left), port, state)
          "mr" -> update_client_pos(Client.modify_pos(client, :right), port, state)
          "mu" -> update_client_pos(Client.modify_pos(client, :up), port, state)
          "md" -> update_client_pos(Client.modify_pos(client, :down), port, state)
          _ -> state
        end

      {:noreply, updated_state}
    else
      {:noreply, state}
    end
  end

  defp update_client_pos(modified_client, port, state) do
    updated_clients = Map.replace!(state.clients, port, modified_client)
    updated_state = %{state | :clients => updated_clients}

    # when a player's position changes we send
    # their new position to all other players
    %{id: id, pos: pos} = modified_client
    data = "u:#{id},#{pos.x},#{pos.y}"
    broadcast(data, port, state)

    updated_state
  end

  defp broadcast(data, port, %{socket: socket, clients: clients}) do
    Map.keys(clients)
    |> Enum.each(fn client_port ->
      if client_port != port, do: send_to_client(socket, client_port, data)
    end)
  end

  defp send_to_client(socket, port, data), do: :gen_udp.send(socket, {127, 0, 0, 1}, port, data)
end
