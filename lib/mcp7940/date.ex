defmodule Soleil.MCP7940.Date do
  alias Circuits.I2C

  import NervesTime.RealTimeClock.BCD

  @address 0x6F
  @register_address 0x00
  @num_bytes 7

  @spec read(I2C.Bus.t(), integer()) :: {:ok, NaiveDateTime.t()} | {:error, any()}
  def read(i2c, address \\ @address) do
    with {:ok, date_regs} <- I2C.write_read(i2c, address, <<@register_address>>, @num_bytes),
         :ok <- is_started(date_regs) do
      decode(date_regs)
    end
  end

  @spec write(I2C.Bus.t(), integer(), NaiveDateTime.t()) :: :ok | {:error, any()}
  def write(i2c, address \\ @address, datetime) do
    with {:ok, registers} <- encode(datetime),
         :ok <- I2C.write(i2c, address, <<@register_address, registers::binary>>) do
      :ok
    end
  end

  def is_started(<<0::1, _rest::55>>), do: {:error, :rtc_not_started}
  def is_started(<<1::1, _rest::55>>), do: :ok
  def is_started(_invalid), do: {:error, :invalid_format}

  @spec decode(binary()) :: {:ok, NaiveDateTime.t()} | {:error, any()}
  def decode(
        <<_pad0::1, second_bcd::7, _pad1::1, min_bcd::7, _pad2::2, hour_bcd::6, _pad3::8,
          _pad4::2, day_bcd::6, _pad5::3, month_bcd::5, year_bcd::8>>
      ) do
    NaiveDateTime.new(
      2000 + to_integer(year_bcd),
      to_integer(month_bcd),
      to_integer(day_bcd),
      to_integer(hour_bcd),
      to_integer(min_bcd),
      to_integer(second_bcd)
    )
  end

  def decode(_invalid), do: {:error, :invalid_format}

  def encode(%NaiveDateTime{year: year} = datetime) when year > 2000 and year < 2100 do
    pad = 0
    enable = 1

    registers =
      <<enable::1, from_integer(datetime.second)::7, pad::1, from_integer(datetime.minute)::7,
        pad::2, from_integer(datetime.hour)::6, pad::4, enable::1, Date.day_of_week(datetime)::3,
        pad::2, from_integer(datetime.day)::6, pad::2, leap_year(datetime)::1,
        from_integer(datetime.month)::5, from_integer(datetime.year - 2000)::8>>

    {:ok, registers}
  end

  def encode(_datetime), do: {:error, :invalid_datetime}

  defp leap_year(datetime) do
    if Date.leap_year?(datetime), do: 1, else: 0
  end
end

#    RTCTIME REGISTER
#    1 0 0 0  0 0 0 1
#    0 1 0 0  0 1 0 1
#    0 0 0 0  1 0 0 1
#    0 0 1 0  1 0 1 1
#    0 0 0 1  0 1 1 0
#    0 0 1 1  0 0 0 0
#    0 0 0 0  0 0 1 1

#    ALARM1 REGISTERS
#    0 0 0 1  0 0 1 1 
#    0 0 1 1  0 1 1 1
#    0 0 0 0  1 0 0 1
#    0 1 1 1  0 0 1 1
#    0 0 0 1  0 1 1 0
#    0 0 0 1  0 0 0 0
#    0 0 1 0  0 0 0 0
