defmodule Soleil do
  @moduledoc ~S"""
  The official support library for the [Soleil](https://protolux.io/soleil) power
  management and sleep control board for Raspberry Pi.

  This library provides functions for managing device power, scheduling sleep 
  durations and wake times, as well as reading battery information. It is designed 
  to abstract low-level hardware interactions, providing a clean and intuitive API 
  for developers.
  """

  use GenServer

  alias Soleil.MCP7940
  alias Soleil.BQ27427
  alias Circuits.I2C

  require Logger

  @type battery_info :: %{
          state_of_charge: float(),
          voltage: float(),
          current: float(),
          temperature: float()
        }

  @default_opts [
    i2c_bus: "i2c-1",
    battery_capacity: 2000,
    battery_energy: 7400
  ]

  @doc ~S"""
  Starts the Soleil GenServer process.

  This function initializes the state and prepares the library for use.

  ## Options
  - `:i2c_bus` - The I2C bus to use for hardware communication (default: `"i2c-1"`).
  - `:battery_capacity` - The rated battery capacity in mAh (default: 2000).
  - `:battery_energy` - The rated battery power in mWh (default: 7400).

  ## Examples

      iex> {:ok, pid} = Soleil.start_link(battery_capacity: 1000, battery_energy: 3700)
      iex> is_pid(pid)
      true
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc ~S"""
  Powers off the device.

  On supported hardware, this will initiate a shutdown sequence. On host 
  environments (e.g., during development), it simulates the power-off behavior.

  ## Examples

      iex> :ok = Soleil.power_off()
  """
  @spec power_off() :: :ok | {:error, any()}
  def power_off() do
    GenServer.call(__MODULE__, :power_off)
  end

  @doc ~S"""
  Puts the device to sleep for a specified duration.

  The device will enter a low-power state and wake up after the specified duration.

  ## Parameters
  - `duration` - The duration to sleep.
  - `unit` - the unit of duration.

  ## Examples

      iex> Soleil.sleep_for(60) # Sleep for 1 minute
      :ok

  """
  @spec sleep_for(non_neg_integer(), :day | :hour | :minute | System.time_unit()) ::
          :ok | {:error, any()}
  def sleep_for(duration, unit \\ :second) do
    GenServer.call(__MODULE__, {:sleep_for, duration, unit})
  end

  @doc ~S"""
  Puts the device to sleep until a specified datetime.

  The device will enter a low-power state and wake up at the specified time.

  ## Parameters
  - `datetime` - A UTC `NaiveDateTime` representing the target wake-up time.

  ## Examples

      iex> :ok = Soleil.sleep_until(~N[2024-11-17 08:30:00])
  """
  @spec sleep_until(NaiveDateTime.t()) :: :ok | {:error, any()}
  def sleep_until(datetime) do
    GenServer.call(__MODULE__, {:sleep_until, datetime})
  end

  @doc ~S"""
  Reads battery information from the hardware.

  This function queries the battery for its state of charge, voltage, 
  average current consumption, and temperature.

  ## Examples

      iex> {:ok, info} = Soleil.battery_info()
      iex> Map.keys(info)
      [:state_of_charge, :voltage, :current, :temperature]

  """
  @spec battery_info() :: {:ok, battery_info()} | {:error, any()}
  def battery_info() do
    GenServer.call(__MODULE__, :battery_info)
  end

  @doc """
  Reports the reason that the board woke from sleep.

  Reasons for wakeup include:
  - `:alarm`: when the RTC alarm triggers wakeup, such as after `sleep_for/2` or `sleep_until/1`
  - `:manual`: when the pushbutton or hall sensor triggers wakeup

  ## Examples

      iex> Soleil.wakeup_reason()
      :manual
    
  """
  @spec wakeup_reason() :: :alarm | :manual
  def wakeup_reason() do
    GenServer.call(__MODULE__, :wakeup_reason)
  end

  @doc ~S"""
  Updates the configuration of the BQ27427 battery fuel gauge chip.

  Accepts the same parameters as `start_link/1`.

  ## Examples

      iex> Soleil.configure_fuel_gauge(battery_capacity: 1000, battery_energy: 3700)
      :ok

  """
  @spec configure_fuel_gauge(keyword()) :: :ok | {:error, any()}
  def configure_fuel_gauge(opts) do
    GenServer.call(__MODULE__, {:configure_fuel_gauge, opts})
  end

  ## GenServer Callbacks

  def init(opts) do
    # Open I2C connection and store in state
    {:ok, i2c_ref} = I2C.open(opts[:i2c_bus])

    state = %{
      i2c: i2c_ref,
      battery_capacity: opts[:battery_capacity],
      battery_energy: opts[:battery_energy],
      wakeup_reason: :manual
    }

    with {:ok, :fuel_gauge} <- {init_bq27427(state), :fuel_gauge},
         {true, :rtc_alarm_status} <- {MCP7940.alarm_flag?(i2c_ref), :rtc_alarm_status},
         {:ok, :rtc_clear_alarm} <- {MCP7940.clear_alarm(i2c_ref), :rtc_clear_alarm} do
      {:ok, %{state | wakeup_reason: :alarm}}
    else
      {false, :rtc_alarm_status} ->
        {:ok, state}

      {error, step} ->
        Logger.error("Failed to initialize Soleil (#{inspect(step)}): #{inspect(error)}")
        {:stop, :failed}
    end
  end

  def handle_call({:configure_fuel_gauge, opts}, _from, state) do
    battery_opts =
      Keyword.take(opts, [:battery_capacity, :battery_energy])
      |> Map.new()

    state = Map.merge(state, battery_opts)

    {:reply, init_bq27427(state, force: true), state}
  end

  def handle_call(:wakeup_reason, _from, state) do
    {:reply, state.wakeup_reason, state}
  end

  def handle_call(:power_off, _from, state) do
    # Write to power management IC to power off the device
    do_power_off()
    {:reply, :ok, state}
  end

  def handle_call(:battery_info, _from, state) do
    # Query battery information

    with {:ok, soc} <- BQ27427.state_of_charge(state.i2c),
         {:ok, voltage} <- BQ27427.voltage(state.i2c),
         {:ok, current} <- BQ27427.current(state.i2c),
         {:ok, temperature} <- BQ27427.temperature(state.i2c) do
      battery_info = %{
        state_of_charge: soc,
        voltage: voltage,
        current: current,
        temperature: temperature
      }

      {:reply, {:ok, battery_info}, state}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:sleep_for, duration, unit}, _from, state) do
    result =
      with {:ok, rtc_time} <- MCP7940.read_time(state.i2c),
           wake_at <- NaiveDateTime.add(rtc_time, duration, unit),
           :ok <- MCP7940.set_alarm(state.i2c, wake_at),
           :ok <- MCP7940.set_alarm_enabled(state.i2c, true) do
        do_power_off()
      end

    {:reply, result, state}
  end

  ## Private Functions

  @spec init_bq27427(map(), keyword()) :: :ok | {:error, any()}
  defp init_bq27427(state, opts \\ []) do
    {:ok, %{itpor: needs_configured?}} = BQ27427.flags(state.i2c)

    if needs_configured? or Keyword.get(opts, :force, false) do
      Logger.info("Configuring BQ27427 battery fuel gauge")

      with {:ok, :unseal} <- {BQ27427.unseal(state.i2c), :unseal},
           {:ok, :enter_config_mode} <-
             {BQ27427.enter_config_mode(state.i2c), :enter_config_mode},
           {:ok, :set_chemistry_id} <-
             {BQ27427.set_chemistry_id(state.i2c, :chemistry_b), :set_chemistry_id},
           {:ok, :set_design_capacity} <-
             {BQ27427.set_design_capacity(state.i2c, state.battery_capacity),
              :set_design_capacity},
           {:ok, :set_design_energy} <-
             {BQ27427.set_design_energy(state.i2c, state.battery_energy), :set_design_energy},
           {:ok, :set_charge_direction} <-
             {BQ27427.set_charge_direction(state.i2c), :set_charge_direction},
           {:ok, :soft_reset} <- {BQ27427.soft_reset(state.i2c), :soft_reset} do
        :ok
      else
        {error, step} ->
          Logger.error("failed to configure BQ27427 (#{inspect(step)}): #{inspect(error)}")
          {:error, step}

        error ->
          Logger.error("unknown error while configuring BQ27427: #{inspect(error)}")
          error
      end
    else
      :ok
    end
  end

  if Mix.target() == :host do
    defp do_power_off() do
      Logger.error("Received poweroff request")
      :erlang.exit(:power_off)
    end
  else
    defp do_power_off(), do: Nerves.Runtime.poweroff()
  end
end
