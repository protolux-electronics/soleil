defmodule Soleil.MCP7940.Alarm do
  defstruct [:wake_at, polarity: :low, set?: false]

  @typedoc """
  The polarity of the multi-functional pin output pin when set
  """
  @type polarity :: :high | :low

  @type t :: %__MODULE__{
          wake_at: NaiveDateTime.t(),
          polarity: polarity(),
          set?: boolean()
        }

  alias Soleil.MCP7940
  alias Circuits.I2C

  import NervesTime.RealTimeClock.BCD
  import Bitwise, only: [&&&: 2]

  require Logger

  @address 0x6F
  @alarm_address 0x11
  @num_bytes 6
  @alarm_flag_reg 0x14

  @spec clear_alarm(I2C.bus(), integer()) :: :ok | {:error, any()}
  def clear_alarm(i2c, address \\ @address) do
    case I2C.write_read(i2c, address, <<@alarm_flag_reg>>, 1) do
      {:ok, <<alarm_reg>>} ->
        I2C.write(i2c, address, <<@alarm_flag_reg, alarm_reg &&& 0xF7>>)

      error ->
        error
    end
  end

  @spec read(I2C.Bus.t(), integer()) :: {:ok, Alarm.t()} | {:error, any()}
  def read(i2c, address \\ @address) do
    with {:ok, rtc_time} <- MCP7940.Date.read(i2c, address),
         {:ok, alarm_regs} <- I2C.write_read(i2c, address, <<@alarm_address>>, @num_bytes) do
      decode(alarm_regs, rtc_time)
    end
  end

  @spec write(I2C.Bus.t(), integer(), Alarm.t()) :: :ok | {:error, any()}
  def write(i2c, address \\ @address, alarm) do
    with {:ok, rtc_time} <- MCP7940.Date.read(i2c, address),
         :ok <- ensure_valid(rtc_time, alarm.wake_at),
         {:ok, alarm_registers} <- encode(alarm) do
      I2C.write(i2c, address, <<@alarm_address, alarm_registers::binary>>)
    end
  end

  @spec decode(binary(), NaiveDateTime.t()) :: {:ok, Alarm.t()} | {:error, any()}
  def decode(
        <<_pad0::1, second_bcd::7, _pad1::1, min_bcd::7, _pad2::2, hour_bcd::6, polarity::1,
          _pad3::3, flag::1, _weekday_bcd::3, _pad4::2, day_bcd::6, _pad5::3, month_bcd::5>>,
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

    {:ok,
     %__MODULE__{
       wake_at: next_alarm,
       set?: flag > 0,
       polarity: if(polarity > 0, do: :high, else: :low)
     }}
  end

  def decode(_invalid, _rtc_time), do: {:error, :invalid_format}

  @spec encode(Alarm.t()) :: {:ok, binary()} | {:error, any()}
  def encode(%__MODULE__{} = alarm) do
    pad = 0
    mask = 0x07

    datetime = alarm.wake_at

    registers =
      <<pad::1, from_integer(datetime.second)::7, pad::1, from_integer(datetime.minute)::7,
        pad::2, from_integer(datetime.hour)::6, polarity(alarm.polarity)::1, mask::3, pad::1,
        Date.day_of_week(datetime)::3, pad::2, from_integer(datetime.day)::6, pad::3,
        from_integer(datetime.month)::5>>

    {:ok, registers}
  end

  def encode(_other), do: {:error, :invalid_alarm}

  defp polarity(:high), do: 1
  defp polarity(:low), do: 0

  @spec ensure_valid(NaiveDateTime.t(), NaiveDateTime.t()) :: :ok | {:error, :invalid_alarm}
  defp ensure_valid(rtc_time, alarm_time) do
    if NaiveDateTime.after?(alarm_time, rtc_time) and
         NaiveDateTime.diff(alarm_time, rtc_time, :day) < 365 do
      :ok
    else
      {:error, :invalid_alarm}
    end
  end
end
