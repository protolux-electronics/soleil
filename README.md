# README 

[Soleil](https://protolux.io/soleil) is an open source power management and sleep control board for Raspberry Pi. It was designed to be used in low power Nerves projects.

This is the officially-supported library for drivers and functions to control the Soleil hardware. It includes features to set the time

Includes a NervesTime.RealTimeClock implementation for the Microchip MCP7940 real-time clock, with additional functions for setting alarms, storing data in SRAM, and more.

## Installation

The package can be installed by adding `soleil` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:soleil, "~> 0.1.0"}
  ]
end
```

The docs can be found at <https://hexdocs.pm/soleil>.

