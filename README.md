# Soleil

The officially-supported library for drivers and functions to control the Soleil low-power solar battery charger board for Raspberry Pi.

Includes a NervesTime.RealTimeClock implementation for the Microchip MCP7940 real-time clock, with additional functions for setting alarms, storing data in SRAM, and more.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `soleil` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:soleil, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/soleil>.

