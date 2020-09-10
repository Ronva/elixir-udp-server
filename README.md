# UdpServer

## Structure

Application - Spins up a supervisor that watches a UDP server and a state container.

UDP server - Used to manage UDP messages between elixir and a [rust game](https://github.com/Ronva/rust-game).

State container - A process used to sync state with any other process. Used for state recovery on process restart.

## Running locally

`iex -S mix`
