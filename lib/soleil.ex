defmodule Soleil do
  use GenServer

  alias Circuits.I2C
  alias Soleil.MCP7940.Alarm

  @default_i2c "i2c-1"

  def start_link(args) do
    name =
      Keyword.get(args, :name) ||
        raise ArgumentError, "Parameter `:name` is required to start Soleil"

    GenServer.start_link(__MODULE__, args, name: name)
  end

  @spec sleep_for(GenServer.server(), :infinity) :: none()
  def sleep_for(_soleil, :infinity) do
    if Code.loaded?(Nerves.Runtime), do: Nerves.Runtime.poweroff()
  end

  @spec sleep_for(
          GenServer.server(),
          non_neg_integer(),
          :day | :hour | :minute | System.time_unit()
        ) ::
          none()
  def sleep_for(soleil, duration, unit \\ :second) do
    wake_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(duration, unit)

    GenServer.call(soleil, {:wake_at, wake_at})
  end

  @impl true
  def init(opts) do
    bus_name = Keyword.get(opts, :bus_name, @default_i2c)

    with {:ok, i2c} <- I2C.open(bus_name), :ok <- maybe_clear_rtc_alarm(i2c) do
      {:ok, %{i2c: i2c}}
    end
  end

  defp maybe_clear_rtc_alarm(i2c) do
    case Alarm.read(i2c) do
      {:ok, %Alarm{set?: true}} ->
        Alarm.clear_alarm(i2c)

      _else ->
        :ok
    end
  end

  @impl true
  def handle_call({:wake_at, datetime}, _from, state) do
    alarm = %Alarm{wake_at: datetime}

    case Alarm.write(state.i2c, alarm) do
      :ok ->
        if Code.loaded?(Nerves.Runtime), do: Nerves.Runtime.poweroff()
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end
end
