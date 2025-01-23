# Getting Started

To get started building your application with Soleil, you need to have a Raspberry Pi and the Soleil hardware. A Raspberry Pi Zero 2W is recommended as it is the most power efficient of the product line, but any Raspberry Pi-compatible board will do. A pre-build Nerves system is available for the Raspberry Pi Zero 2W.
## Mounting the board

The top face of Soleil is the side with the connectors and chips. The Raspberry Pi headers insert from the bottom, through the holes in the bottom of the board. See the below reference image:

![Mounting your Soleil board on a Raspberry Pi](https://github.com/protolux-electronics/soleil_hardware/raw/main/docs/images/soleil.jpg)

> #### Check the mounting orientation {: .warning}
> Mounting the board upside down may damage your Raspberry Pi, so please ensure the correct orientation before applying any power source!

## Battery and Solar Panel Selection

Soleil is designed to be compatible with [LiPo batteries from Adafruit](https://www.adafruit.com/category/574). While other vendors will have compatible batteries, Adafruit maintains a high-quality product lineup and is widely available. If using batteries sourced from another vendor, ensure that the batteries have a 2-pin JST PH connector with the positive terminal on the left (pin 1). Other battery chemistries (such as NiMH, NiCad, or LiFePO4) are NOT supported - only standard 3.7V lithium polymer batteries.

Different sized batteries have different capabilities when it comes to charging and discharging rates. We recommend a battery with a capacity of at least 1000mAh and a C rating of at least 1C. 

For solar panels, any panels up to 16V are supported. Do note that the battery charger chip does not start charging until the voltages reaches 4V. For a 6V solar panel, this means that slow charging will likely not occur in overcast or shaded conditions, and can only happen while exposed to direct sunlight. Connected multiple panels in parallel can alleviate this issue, but it is important to stress that the rated open-circuit voltage of your panels should not exceed 16V.

> #### Our recommendation {: .info}
> We like the panels from [Voltaic Systems](https://voltaicsystems.com) as they are high quality and weather-resistant.

## Nerves System

A prebuilt Nerves system is available for the Raspberry Pi Zero 2W. To target this system, add it and the target to your dependencies in `mix.exs`:

```elixir
defmodule MyApp.MixProject do

  # ...

  @all_targets ["...", :soleil_rpi0_2]

  # ...

  defp deps do
    [
      # ...
      {:soleil_system_rpi0_2, "~> 1.28.1", runtime: false, targets: :soleil_rpi0_2},
      # ...
    ]
  end

  # ...

end
```

Then make sure to set the target as an environment variable:

```sh
export MIX_TARGET="soleil_rpi0_2"
```

Finally run `mix deps.get` to fetch the prebuilt system archive.

## Library Installation

To install and use the driver library, add it to your dependencies in `mix.exs`:

```elixir
defmodule MyApp.MixProject do

  # ...

  defp deps do
    [
      # ...
      {:soleil, "~> 0.1.0"},
      # ...
    ]
  end

  # ...
end
```

Then, add `Soleil` to your supervision tree in `application.ex`:

```elixir
defmodule MyApp.Application do

  # ...

  @impl true
  def start(_type, _args) do
    children =
      [
        # ...
        {Soleil, battery_capacity: 2000, battery_energy: 7400},
        # ...
      ]

    opts = [strategy: :one_for_one, name: SoleilDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # ...

end
```

> #### Start Soleil early in the supervision tree {: .info}
> Be sure to start `Soleil` before any other processes which might call its functions. 

The parameters `battery_capacity` (in mAh) and `battery_energy` (in mWh) can be obtained from your battery's datasheet. If your battery does not have a rated energy, multiply the rated capacity by the nominal voltage (usually 3.7V for lithium polymer batteries). These parameters provide the proper information for the battery fuel gauge algorithm.

## Usage

Soleil exposes several convenience functions for querying the state of the battery, as well as control the sleep modes. For documentation on the functions, see the `Soleil` module. For a complete usage example, see the Soleil demo project.
