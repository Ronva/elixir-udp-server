defmodule UdpServer.Utils do
  def parse_ipv4(ip_string) do
    ip_string
    |> String.split(".")
    |> List.to_tuple()
  end

  def gen_id(clients) when clients == %{}, do: 1

  def gen_id(clients) when clients != %{} do
    Map.values(clients)
    |> Enum.map(fn %{id: id} -> id end)
    |> Enum.max()
    # increment id
    |> Kernel.+(1)
  end
end
