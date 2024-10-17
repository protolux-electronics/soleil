defmodule Soleil.MCP7940.AlarmTest do
  use ExUnit.Case

  alias Soleil.MCP7940

  doctest Soleil.MCP7940.Alarm

  test "alarm registers encode and decode correctly" do
    datetime =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> NaiveDateTime.add(3, :hour)

    alarm = %MCP7940.Alarm{enabled?: true, datetime: datetime, polarity: :low}

    enabled = <<0x20>>

    {:ok, registers} = MCP7940.Alarm.encode(alarm)
    {:ok, test_alarm} = MCP7940.Alarm.decode(registers, enabled, NaiveDateTime.utc_now())

    assert alarm == test_alarm
    assert :erlang.size(registers) == 6
  end

  test "clear alarm" do
    alarm = %MCP7940.Alarm{enabled?: false}

    disabled = <<0x00>>

    {:ok, registers} = MCP7940.Alarm.encode(alarm)
    {:ok, test_alarm} = MCP7940.Alarm.decode(registers, disabled, NaiveDateTime.utc_now())

    assert alarm == test_alarm
    assert :erlang.size(registers) == 6
  end
end
