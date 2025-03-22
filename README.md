# README

[Soleil](https://protolux.io/soleil) is an open source power management and
sleep control board for Raspberry Pi. It was designed to be used in low power
Nerves projects.

This is the officially-supported library for drivers and functions to control
the Soleil hardware. It consists of several main parts:

- Drivers:
  - `NervesTime.RealTimeClock` implementation for the Microchip `MCP7940N`.
    There are additional functions included for setting alarms.
  - A driver for the `BQ27427` lithium battery fuel gauge chip, including
    functions to configure the connected battery parameters, read the battery
    state of charge/voltage/current, as well as set low-battery thresholds
- Helpers:
  - The `Soleil` GenServer helps your application initialize the connected
    components, and serves as the high level interface for power control. It
    includes helpers to enter low power mode, set the sleep duration or wake
    time, and easily read out battery state.

## Installation

The package can be installed by adding `soleil` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:soleil, "~> 0.1.0"}
  ]
end
```

The docs can be found at <https://hexdocs.pm/soleil>.
