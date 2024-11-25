defmodule Soleil.MCP7940 do
  @moduledoc """
  Microchip MCP7940 RTC implementation for NervesTime.

  To configure NervesTime to use this module, update the `:nerves_time` application
  environment like this:

  ```elixir
  config :nerves_time, rtc: Soleil.MCP7940
  ```

  Check the logs for error message if the RTC doesn't appear to work.

  See [the datasheet](https://ww1.microchip.com/downloads/en/devicedoc/20005010f.pdf)
  for implementation details
  """

  @behaviour NervesTime.RealTimeClock

  require Logger

  alias Circuits.I2C

  import Bitwise, only: [|||: 2, &&&: 2]
  import NervesTime.RealTimeClock.BCD

  @i2c_address 0x6F
  @default_bus_name "i2c-1"

  @reg_time 0x00
  @reg_control 0x07
  @reg_alarm0 0x0A
  @reg_flag0 0x0D

  @time_bytes 7
  @alarm_bytes 6

  @impl NervesTime.RealTimeClock
  def init(args) do
    bus_name = Keyword.get(args, :bus_name, @default_bus_name)

    case I2C.open(bus_name) do
      {:ok, i2c} -> {:ok, %{i2c: i2c, bus_name: bus_name}}
      error -> error
    end
  end

  @impl NervesTime.RealTimeClock
  def terminate(state), do: I2C.close(state.i2c)

  @impl NervesTime.RealTimeClock
  def get_time(state) do
    case read_time(state.i2c) do
      {:ok, datetime} -> {:ok, datetime, state}
      {:error, :rtc_not_started} -> {:unset, state}
      error -> error
    end
  end

  @impl NervesTime.RealTimeClock
  def set_time(state, datetime) do
    case write_time(state.i2c, datetime) do
      :ok -> state
      error -> error
    end
  end

  @spec read_time(I2C.bus()) :: {:ok, NaiveDateTime.t()} | {:error, any()}
  def read_time(i2c) do
    case I2C.write_read(i2c, @i2c_address, <<@reg_time>>, @time_bytes) do
      {:ok, registers} -> decode_registers(registers)
      error -> error
    end
  end

  @spec write_time(I2C.bus(), NaiveDateTime.t()) :: :ok | {:error, any()}
  def write_time(i2c, datetime) do
    case encode_registers(datetime) do
      {:ok, registers} -> I2C.write(i2c, @i2c_address, <<@reg_time, registers::binary>>)
      error -> error
    end
  end

  @spec set_alarm(I2C.bus(), NaiveDateTime.t()) :: :ok | {:error, any()}
  def set_alarm(i2c, alarm) do
    with {:ok, rtc_time} <- read_time(i2c),
         {:ok, alarm_regs} <- encode_alarm(alarm, rtc_time) do
      I2C.write(i2c, @i2c_address, <<@reg_alarm0, alarm_regs::binary>>)
    end
  end

  @spec get_alarm(I2C.bus()) :: {:ok, NaiveDateTime.t()} | {:error, any()}
  def get_alarm(i2c) do
    with {:ok, rtc_time} <- read_time(i2c),
         {:ok, alarm_regs} <- I2C.write_read(i2c, @i2c_address, <<@reg_alarm0>>, @alarm_bytes) do
      decode_alarm(alarm_regs, rtc_time)
    end
  end

  @spec alarm_enabled?(I2C.bus()) :: boolean() | {:error, any()}
  def alarm_enabled?(i2c) do
    case I2C.write_read(i2c, @i2c_address, <<@reg_control>>, 1) do
      {:ok, <<control>>} -> (control ||| 0x10) > 0
      error -> error
    end
  end

  @spec set_alarm_enabled(I2C.bus(), boolean()) :: :ok | {:error, any()}
  def set_alarm_enabled(i2c, true), do: I2C.write(i2c, @i2c_address, <<@reg_control, 0x90>>)
  def set_alarm_enabled(i2c, false), do: I2C.write(i2c, @i2c_address, <<@reg_control, 0x80>>)

  @spec alarm_flag?(I2C.bus()) :: boolean() | {:error, any()}
  def alarm_flag?(i2c) do
    case I2C.write_read(i2c, @i2c_address, <<@reg_flag0>>, 1) do
      {:ok, <<reg>>} -> (reg &&& 0x08) > 0
      error -> error
    end
  end

  @spec clear_alarm(I2C.bus()) :: :ok | {:error, any()}
  def clear_alarm(i2c) do
    case I2C.write_read(i2c, @i2c_address, <<@reg_alarm0 + 3>>, 1) do
      {:ok, <<reg>>} -> I2C.write(i2c, @i2c_address, <<@reg_flag0, reg &&& 0xF7>>)
      error -> error
    end
  end

  ########## TIMEKEEPING ###########

  @spec decode_registers(binary()) :: {:ok, NaiveDateTime.t()} | {:error, any()}
  defp decode_registers(<<0::1, _rest::55>>), do: {:error, :rtc_not_started}

  defp decode_registers(
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

  defp decode_registers(_invalid), do: {:error, :invalid_format}

  @spec encode_registers(NaiveDateTime.t()) :: {:ok, binary()} | {:error, any()}
  defp encode_registers(%NaiveDateTime{year: year} = datetime) when year > 2000 and year < 2100 do
    pad = 0
    enable = 1

    registers =
      <<enable::1, from_integer(datetime.second)::7, pad::1, from_integer(datetime.minute)::7,
        pad::2, from_integer(datetime.hour)::6, pad::4, enable::1, Date.day_of_week(datetime)::3,
        pad::2, from_integer(datetime.day)::6, pad::2, leap_year(datetime)::1,
        from_integer(datetime.month)::5, from_integer(datetime.year - 2000)::8>>

    {:ok, registers}
  end

  defp encode_registers(_datetime), do: {:error, :invalid_datetime}

  defp leap_year(datetime) do
    if Date.leap_year?(datetime), do: 1, else: 0
  end

  ########## ALARMS ###########

  @spec decode_alarm(binary(), NaiveDateTime.t()) :: {:ok, NaiveDateTime.t()} | {:error, any()}
  defp decode_alarm(
         <<_pad0::1, second_bcd::7, _pad1::1, min_bcd::7, _pad2::2, hour_bcd::6, _polarity::1,
           _pad3::3, _flag::1, _weekday_bcd::3, _pad4::2, day_bcd::6, _pad5::3, month_bcd::5>>,
         %NaiveDateTime{year: rtc_year} = rtc_time
       ) do
    next_alarm =
      [rtc_year, rtc_year + 1]
      |> Enum.map(fn year ->
        case NaiveDateTime.new(
               year,
               to_integer(month_bcd),
               to_integer(day_bcd),
               to_integer(hour_bcd),
               to_integer(min_bcd),
               to_integer(second_bcd)
             ) do
          {:ok, dt} -> dt
          {:error, _reason} -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.find(fn dt ->
        NaiveDateTime.after?(dt, rtc_time)
      end)

    {:ok, next_alarm}
  end

  defp decode_alarm(_invalid, _rtc_time), do: {:error, :invalid_format}

  @spec encode_alarm(NaiveDateTime.t(), NaiveDateTime.t()) :: {:ok, binary()} | {:error, any()}

  defp encode_alarm(datetime, rtc_time) do
    with true <- NaiveDateTime.after?(datetime, rtc_time),
         diff when diff < 365 <- NaiveDateTime.diff(datetime, rtc_time, :day) do
      pad = 0
      polarity = 0
      mask = 0b111

      registers =
        <<pad::1, from_integer(datetime.second)::7, pad::1, from_integer(datetime.minute)::7,
          pad::2, from_integer(datetime.hour)::6, polarity::1, mask::3, pad::1,
          Date.day_of_week(datetime)::3, pad::2, from_integer(datetime.day)::6, pad::3,
          from_integer(datetime.month)::5>>

      {:ok, registers}
    else
      _error -> {:error, :invalid_alarm}
    end
  end
end
