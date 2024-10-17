defmodule Soleil.MCP7940.DateTest do
  use ExUnit.Case

  alias Soleil.MCP7940

  doctest Soleil.MCP7940.Date

  test "date registers encode and decode correctly" do
    datetime =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)

    {:ok, registers} = MCP7940.Date.encode(datetime)
    {:ok, test_datetime} = MCP7940.Date.decode(registers)

    assert datetime == test_datetime
    assert :erlang.size(registers) == 7
  end

  test "date does not encode for invalid dates" do
    {:ok, future} = NaiveDateTime.new(2101, 1, 1, 0, 0, 0, 0)
    {:ok, past} = NaiveDateTime.new(1999, 1, 1, 0, 0, 0, 0)

    assert MCP7940.Date.encode(future) == {:error, :invalid_datetime}
    assert MCP7940.Date.encode(past) == {:error, :invalid_datetime}
  end

  test "leap year" do
    {:ok, leap_day} = NaiveDateTime.new(2024, 2, 29, 0, 0, 0, 0)

    {:ok, registers} = MCP7940.Date.encode(leap_day)
    <<_sec, _min, _hour, _weekday, _date, _pad::2, leap_year::1, _month::5, _year>> = registers
    assert leap_year == 1

    {:ok, datetime} = MCP7940.Date.decode(registers)
    assert Date.leap_year?(datetime)
  end
end
