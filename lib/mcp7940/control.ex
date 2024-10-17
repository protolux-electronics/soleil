defmodule Soleil.MCP7940.Control do
  alias Circuits.I2C

  @address 0x6F
  @control_address 0x07

  @spec enable_alarm(I2C.bus(), integer()) :: :ok | {:error, any()}
  def enable_alarm(i2c, address \\ @address) do
    I2C.write(i2c, address, <<@control_address, 0xA0>>)
  end

  @spec disable_alarm(I2C.bus(), integer()) :: :ok | {:error, any()}
  def disable_alarm(i2c, address \\ @address) do
    I2C.write(i2c, address, <<@control_address, 0x80>>)
  end

  @spec alarm_enabled?(I2C.bus(), integer()) :: boolean()
  def alarm_enabled?(i2c, address \\ @address) do
    case I2C.write_read(i2c, address, <<@control_address>>, 1) do
      {:ok, <<_pad0::2, enabled::1, _pad1::5>>} -> enabled > 0
      _error -> false
    end
  end
end
