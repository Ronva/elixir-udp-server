defmodule UdpServer.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    default_container_state = %{socket: nil, clients: %{}}

    children = [
      {UdpServer.Container, default_container_state},
      {UdpServer.Server, 2052}
    ]

    opts = [strategy: :rest_for_one, name: UdpServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
