defmodule Server do
  @enforce_keys [:room_id, :addr, :port]
  defstruct room_id: nil, addr: nil, port: nil
end

defmodule UdpServer.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    default_container_state = %{socket: nil, clients: %{}}

    children = [
      {UdpServer.Container, default_container_state},
      {UdpServer.Server, %Server{room_id: 1, addr: {224,0,0,251}, port: 2052}}
    ]

    opts = [strategy: :rest_for_one, name: UdpServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
