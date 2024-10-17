defmodule Soleil.MCP7940 do
  @moduledoc """
  Microchip MCP7940 RTC implementation for NervesTime

  To configure NervesTime to use this module, update the `:nerves_time` application
  environment like this:

  ```elixir
  config :nerves_time, rtc: Soleil.MCP7940
  ```

  If not using `"i2c-1"` or the default I2C bus address, specify them like this:

  ```elixir
  config :nerves_time, rtc: {Soleil.MCP7940, [bus_name: "i2c-2", address: 0x6F]}
  ```

  Check the logs for error message if the RTC doesn't appear to work.

  See https://ww1.microchip.com/downloads/en/devicedoc/20005010f.pdf
  for implementation details
  """

  @behaviour NervesTime.RealTimeClock

  require Logger

  alias Soleil.MCP7940
  alias Circuits.I2C

  @default_bus_name "i2c-1"
  @default_address 0x6F

  @type state :: %{
          i2c: I2C.Bus.t(),
          bus_name: String.t(),
          address: I2C.address()
        }

  @impl NervesTime.RealTimeClock
  def init(args) do
    bus_name = Keyword.get(args, :bus_name, @default_bus_name)
    address = Keyword.get(args, :address, @default_address)

    case I2C.open(bus_name) do
      {:ok, i2c} -> {:ok, %{i2c: i2c, bus_name: bus_name, address: address}}
      error -> error
    end
  end

  @impl NervesTime.RealTimeClock
  def terminate(_state), do: :ok

  @impl NervesTime.RealTimeClock
  def get_time(state) do
    case MCP7940.Date.read(state.i2c, state.address) do
      {:ok, datetime} ->
        {:ok, datetime, state}

      {:error, :rtc_not_started} ->
        {:unset, state}

      error ->
        Logger.error("Error reading MCP7849: #{inspect(error)}")
        {:unset, state}
    end
  end

  @impl NervesTime.RealTimeClock
  def set_time(state, datetime) do
    case MCP7940.Date.write(state.i2c, state.address, datetime) do
      :ok ->
        state

      error ->
        Logger.error("Error setting MCP7940 to #{inspect(datetime)}: #{inspect(error)}")
        state
    end
  end
end
