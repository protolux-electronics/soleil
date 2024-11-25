defmodule Soleil.BQ27427 do
  @moduledoc """
  Driver for the Texas Instruments BQ27427 Battery Fuel Gauge.

  This module provides a complete interface to the BQ27427 fuel gauge, including:
  - Battery measurements (voltage, current, power)
  - State of charge and capacity readings
  - Temperature measurements
  - Status flags and control operations
  - Configuration mode management

  """

  alias Circuits.I2C
  import Bitwise
  require Logger

  @type i2c_bus :: Circuits.I2C.bus()

  @typedoc """
  The battery chemistry type. According to the datasheet, the types correspond to 
  the following battery properties:

  `:chemistry_a`: 4.35 V
  `:chemistry_b`: 4.2  V
  `:chemistry_c`: 4.4  V

  Note: `:chemistry_b` corresponds to LiPo batteries, which is the only battery 
  chemistry supported by the battery charger in the Soleil board. Future versions 
  may allow for use with other battery chemistries
  """
  @type chem_id :: :chemistry_a | :chemistry_b | :chemistry_c

  # Device address
  @i2c_address 0x55

  # Standard commands
  @cmd_control 0x00
  @cmd_temp 0x02
  @cmd_voltage 0x04
  @cmd_flags 0x06
  @cmd_rem_capacity 0x0C
  @cmd_full_capacity 0x0E
  @cmd_current 0x10
  @cmd_power 0x18
  @cmd_soc 0x1C

  # Control subcommands
  @control_status 0x0000
  @control_chem_id 0x0008
  @control_set_cfg 0x0013
  @control_seal 0x0020
  @control_chem_a 0x0030
  @control_chem_b 0x0031
  @control_chem_c 0x0032
  @control_reset 0x0041
  @control_soft_reset 0x0042
  @control_unseal 0x8000

  # Data Memory Commands
  @cmd_data_class 0x3E
  @cmd_data_block 0x3F
  @cmd_block_data_start 0x40
  @cmd_block_data_checksum 0x60
  @cmd_block_data_control 0x61

  # Data Memory Classes
  @class_discharge 0x31
  @class_registers 0x40
  @class_state 0x52
  @class_calibration 0x69

  @doc """
  Gets the battery voltage in volts.

  ## Examples

      iex> {:ok, ref} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.voltage(ref)
      {:ok, 3.750}

  """
  @spec voltage(i2c_bus()) :: {:ok, integer()} | {:error, term()}
  def voltage(i2c_ref) do
    case read_register(i2c_ref, @cmd_voltage) do
      {:ok, voltage_mv} -> {:ok, voltage_mv / 1000.0}
      error -> error
    end
  end

  @doc """
  Get the average current in amps. Positive values indicate charging,
  negative values indicate discharging.

  ## Examples

      iex> {:ok, ref} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.current(ref)
      {:ok, -0.250} # Discharging at 250mA

  """
  @spec current(i2c_bus()) :: {:ok, integer()} | {:error, term()}
  def current(i2c_ref) do
    case read_register(i2c_ref, @cmd_current) do
      {:ok, value} -> {:ok, value_to_signed16(value) / 1000.0}
      error -> error
    end
  end

  @doc """
  Get the average power in watts. Positive values indicate charging,
  negative values indicate discharging.

  ## Examples

      iex> {:ok, ref} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.current(ref)
      {:ok, -0.850} # Discharging at 850mW

  """
  @spec power(i2c_bus()) :: {:ok, integer()} | {:error, term()}
  def power(i2c_ref) do
    case read_register(i2c_ref, @cmd_power) do
      {:ok, value} -> {:ok, value_to_signed16(value) / 1000.0}
      error -> error
    end
  end

  @doc """
  Get the state of charge as a percentage (0-100).

  ## Examples

      iex> {:ok, ref} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.state_of_charge(ref)
      {:ok, 37} # battery is at 37%

  """
  @spec state_of_charge(i2c_bus()) :: {:ok, integer()} | {:error, term()}
  def state_of_charge(i2c_ref) do
    read_register(i2c_ref, @cmd_soc)
  end

  @doc """
  Get the internal chip temperature in degrees Celsius. Future versions
  of hardware may support reading temperature from the battery internal
  NTC sensor.

  ## Examples

      iex> {:ok, ref} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.temperature(ref)
      {:ok, 25.7} # chip temperature is  25.7C
  """
  @spec temperature(i2c_bus()) :: {:ok, float()} | {:error, term()}
  def temperature(i2c_ref) do
    case read_register(i2c_ref, @cmd_temp) do
      {:ok, temp} -> {:ok, temp / 10.0 - 273.15}
      error -> error
    end
  end

  @doc """
  Get the remaining capacity in mAh.

  ## Examples

      iex> {:ok, ref} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.remaining_capacity(ref)
      {:ok, 1128} # battery has an estimated 1128mAh remaining

  """
  @spec remaining_capacity(i2c_bus()) :: {:ok, integer()} | {:error, term()}
  def remaining_capacity(i2c_ref) do
    read_register(i2c_ref, @cmd_rem_capacity)
  end

  @doc """
  Get the full charge capacity in mAh.

  ## Examples

      iex> {:ok, ref} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.full_charge_capacity(ref)
      {:ok, 1980} # battery has an estimated capacity of 1980mAh at full charge

  """
  @spec full_charge_capacity(i2c_bus()) :: {:ok, integer()} | {:error, term()}
  def full_charge_capacity(i2c_ref) do
    read_register(i2c_ref, @cmd_full_capacity)
  end

  @doc """
  Get the chemical ID of the battery profile.

  ## Examples

      iex> {:ok, ref} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.chemistry_id(ref)
      {:ok, :chemistry_b} # using chemistry B for SOC algorithm

  """
  @spec chemistry_id(i2c_bus()) :: {:ok, chem_id()} | {:error, term()}
  def chemistry_id(i2c_ref) do
    case control_cmd(i2c_ref, @control_chem_id) do
      {:ok, 0x3230} -> {:ok, :chemistry_a}
      {:ok, 0x1202} -> {:ok, :chemistry_b}
      {:ok, 0x3142} -> {:ok, :chemistry_c}
      error -> error
    end
  end

  @doc """
  Get all status flags as a map.


  ## Examples

      iex> {:ok, ref} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.flags(ref)
      {:ok, %{
        over_temp_flag: false,
        under_temp_flag: false,
        full_charge: false,
        charging: true,
        ocv_taken: true,
        dod_correct: true,
        itpor: false,
        cfgupmode: false,
        bat_det: true,
        soc1: false,
        socf: false,
        discharging: true
      }}

  """
  @spec flags(i2c_bus()) :: {:ok, map()} | {:error, term()}
  def flags(i2c_ref) do
    case read_register(i2c_ref, @cmd_flags) do
      {:ok, flags} ->
        {:ok,
         %{
           over_temp_flag: (flags &&& 1 <<< 15) != 0,
           under_temp_flag: (flags &&& 1 <<< 14) != 0,
           full_charge: (flags &&& 1 <<< 9) != 0,
           charging: (flags &&& 1 <<< 8) != 0,
           ocv_taken: (flags &&& 1 <<< 7) != 0,
           dod_correct: (flags &&& 1 <<< 6) != 0,
           itpor: (flags &&& 1 <<< 5) != 0,
           cfgupmode: (flags &&& 1 <<< 4) != 0,
           bat_det: (flags &&& 1 <<< 3) != 0,
           soc1: (flags &&& 1 <<< 2) != 0,
           socf: (flags &&& 1 <<< 1) != 0,
           discharging: (flags &&& 1) != 0
         }}

      error ->
        error
    end
  end

  @doc """
  Get control status as a map.

  ## Examples

      iex> {:ok, ref} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.control_status(ref)
      {:ok, %{
        sleep: false,
        bca: false,
        calmode: false,
        cca: false,
        chemchange: false,
        initcomp: true,
        ldmd: true,
        qmax_up: false,
        res_up: false,
        rup_dis: true,
        sealed: false,
        shutdown_enabled: false,
        vok: false,
        wdreset: false
      }}

  """
  @spec control_status(i2c_bus()) :: {:ok, map()} | {:error, term()}
  def control_status(i2c_ref) do
    case control_cmd(i2c_ref, @control_status) do
      {:ok, status} ->
        {:ok,
         %{
           shutdown_enabled: (status &&& 1 <<< 15) != 0,
           wdreset: (status &&& 1 <<< 14) != 0,
           sealed: (status &&& 1 <<< 13) != 0,
           calmode: (status &&& 1 <<< 12) != 0,
           cca: (status &&& 1 <<< 11) != 0,
           bca: (status &&& 1 <<< 10) != 0,
           qmax_up: (status &&& 1 <<< 9) != 0,
           res_up: (status &&& 1 <<< 8) != 0,
           initcomp: (status &&& 1 <<< 7) != 0,
           sleep: (status &&& 1 <<< 4) != 0,
           ldmd: (status &&& 1 <<< 3) != 0,
           rup_dis: (status &&& 1 <<< 2) != 0,
           vok: (status &&& 1 <<< 1) != 0,
           chemchange: (status &&& 1) != 0
         }}

      error ->
        error
    end
  end

  @doc """
  Perform a hard reset of the device. This will reset all registers to their default values.
  """
  @spec reset(i2c_bus()) :: :ok | {:error, term()}
  def reset(i2c_ref) do
    case control_cmd(i2c_ref, @control_reset) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Perform a soft reset of the device. This maintains configuration but resets calculations.
  Used to exit configuration mode (has the side effect of re-sealing the device)
  """
  @spec soft_reset(i2c_bus()) :: :ok | {:error, term()}
  def soft_reset(i2c_ref) do
    case control_cmd(i2c_ref, @control_soft_reset) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Enter configuration mode. The device must be unsealed before this can be used.
  """
  @spec enter_config_mode(i2c_bus()) :: :ok | {:error, term()}
  def enter_config_mode(i2c_ref) do
    case control_cmd(i2c_ref, @control_set_cfg) do
      {:ok, _} ->
        # Wait required 1100ms before config can start
        # TODO: poll flags register
        Process.sleep(1100)
        :ok

      error ->
        error
    end
  end

  @doc """
  Unseal the device to allow configuration changes.
  """
  @spec unseal(i2c_bus()) :: :ok | {:error, term()}
  def unseal(i2c_ref) do
    with {:ok, _} <- control_cmd(i2c_ref, @control_unseal),
         {:ok, _} <- control_cmd(i2c_ref, @control_unseal) do
      :ok
    end
  end

  @doc """
  Seal the device to prevent configuration changes.
  """
  @spec seal(i2c_bus()) :: :ok | {:error, term()}
  def seal(i2c_ref) do
    case control_cmd(i2c_ref, @control_seal) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Sets the chemistry ID of the battery profile. The device must be unsealed
  to use this function

  ## Example
      iex> {:ok, i2c} = Circuits.I2C.open("i2c-1")
      iex> Soleil.BQ27427.set_chemistry_id(i2c, :chemistry_a)
      :ok

  """
  @spec set_chemistry_id(i2c_bus(), chem_id()) :: :ok | {:error, term()}
  def set_chemistry_id(i2c_ref, chem_id) do
    cmd = chem_id_to_cmd(chem_id)

    case control_cmd(i2c_ref, cmd) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Sets the design capacity of the battery in mAh. The device must be unsealed
  to use this function

  ## Example

      iex> Soleil.BQ27427.set_design_capacity(i2c, 1200)  # 1200mAh battery

  """
  @spec set_design_capacity(i2c_bus(), integer()) :: :ok | {:error, term()}
  def set_design_capacity(i2c_ref, capacity) when capacity >= 0 and capacity <= 8000 do
    write_data_memory(i2c_ref, @class_state, 0, 6, <<capacity::big-16>>)
  end

  @doc """
  Gets the design capacity of the battery in mAh. The device must be unsealed
  to use this function

  ## Example

      iex> Soleil.BQ27427.get_design_capacity(i2c)
      {:ok, 1200} # 1200 mAh battery

  """
  @spec get_design_capacity(i2c_bus()) :: {:ok, integer()} | {:error, term()}
  def get_design_capacity(i2c_ref) do
    case read_data_memory(i2c_ref, @class_state, 0, 6, 2) do
      {:ok, <<capacity::big-16>>} -> {:ok, capacity}
      error -> error
    end
  end

  @doc """
  Sets the design energy of the battery in mWh. The device must be unsealed
  to use this function

  ## Example
      iex> Soleil.BQ27427.set_design_energy(i2c, 4440)  # 4440mWh battery
  """
  @spec set_design_energy(i2c_bus(), integer()) :: :ok | {:error, term()}
  def set_design_energy(i2c_ref, energy) when energy >= 0 and energy <= 32767 do
    write_data_memory(i2c_ref, @class_state, 0, 8, <<energy::big-16>>)
  end

  @doc """
  Gets the design capacity of the battery in mWh. The device must be unsealed
  to use this function

  ## Example

      iex> Soleil.BQ27427.get_design_energy(i2c)
      {:ok, 3000} # 3000 mWh battery

  """
  @spec get_design_energy(i2c_bus()) :: {:ok, integer()} | {:error, term()}
  def get_design_energy(i2c_ref) do
    case read_data_memory(i2c_ref, @class_state, 0, 8, 2) do
      {:ok, <<energy::big-16>>} -> {:ok, energy}
      error -> error
    end
  end

  @doc """
  Sets the bit to configure sign of the CC_Gain parameter. The default firmware for
  the BQ27427 for some reason shipped with the wrong value, and isn't documented in
  the datasheet. See the TI support issue for more information:

  https://e2e.ti.com/support/power-management-group/power-management/f/power-management-forum/1215460/bq27427evm-misbehaving-stateofcharge

  ## Example

      iex> Soleil.BQ27427.set_charge_direction(i2c)
      :ok

  """
  def set_charge_direction(i2c_ref) do
    case read_data_memory(i2c_ref, @class_calibration, 0, 5, 1) do
      {:ok, <<byte>>} -> write_data_memory(i2c_ref, @class_calibration, 0, 5, <<byte &&& 0x7F>>)
      error -> error
    end
  end

  @doc """
  Configures the GPOUT pin as a State of Charge interrupt with the given threshold.

  ## Parameters
    - threshold: Percentage (0-100) at which to trigger the interrupt
    - clear_threshold: Percentage (0-100) at which to clear the interrupt
    
  ## Example

      iex> Soleil.BQ27427.configure_soc1_interrupt(i2c, 20, 25)  # Trigger at 20%, clear at 25%
  """
  @spec configure_soc1_interrupt(i2c_bus(), integer(), integer()) :: :ok | {:error, term()}
  def configure_soc1_interrupt(i2c_ref, threshold, clear_threshold)
      when threshold >= 0 and threshold <= 100 and clear_threshold >= 0 and clear_threshold <= 100 do
    thresholds = <<threshold, clear_threshold>>

    with :ok <- write_data_memory(i2c_ref, @class_discharge, 0, 0, thresholds),
         {:ok, <<opconfig::big-16>>} <- read_data_memory(i2c_ref, @class_registers, 0, 0, 2) do
      # set BATLOWEN bit (bit 3) 
      new_opconfig = opconfig ||| 0x0004
      write_data_memory(i2c_ref, @class_registers, 0, 0, <<new_opconfig::big-16>>)
    end
  end

  # Private functions

  @spec read_register(i2c_bus(), byte()) :: {:ok, integer()} | {:error, term()}
  defp read_register(i2c_ref, register) do
    case I2C.write_read(i2c_ref, @i2c_address, <<register>>, 2) do
      {:ok, <<value::little-16>>} -> {:ok, value}
      error -> error
    end
  end

  @spec read_byte(i2c_bus(), byte()) :: {:ok, integer()} | {:error, term()}
  defp read_byte(i2c_ref, register) do
    case I2C.write_read(i2c_ref, @i2c_address, <<register>>, 1) do
      {:ok, <<value>>} -> {:ok, value}
      error -> error
    end
  end

  @spec write_register(i2c_bus(), byte(), integer()) :: :ok | {:error, term()}
  defp write_register(i2c_ref, register, value) do
    I2C.write(i2c_ref, @i2c_address, <<register, value::little-16>>)
  end

  @spec write_byte(i2c_bus(), byte(), integer()) :: :ok | {:error, term()}
  defp write_byte(i2c_ref, register, value) do
    I2C.write(i2c_ref, @i2c_address, <<register, value>>)
  end

  @spec control_cmd(i2c_bus(), integer()) :: {:ok, integer()} | {:error, term()}
  defp control_cmd(i2c_ref, command) do
    case write_register(i2c_ref, @cmd_control, command) do
      :ok -> read_register(i2c_ref, @cmd_control)
      error -> error
    end
  end

  @spec write_data_memory(i2c_bus(), integer(), integer(), integer(), binary()) ::
          :ok | {:error, term()}
  defp write_data_memory(i2c_ref, class, block, offset, data) do
    with :ok <- write_byte(i2c_ref, @cmd_block_data_control, 0),
         :ok <- write_byte(i2c_ref, @cmd_data_class, class),
         :ok <- write_byte(i2c_ref, @cmd_data_block, block),
         :ok <- Process.sleep(50),
         {:ok, old_checksum} <- read_byte(i2c_ref, @cmd_block_data_checksum),
         {:ok, old_data} <- read_block_data(i2c_ref, offset, byte_size(data)),
         # Write new data
         :ok <- write_block_data(i2c_ref, offset, data),
         # Calculate new checksum
         new_checksum = calculate_new_checksum(old_checksum, old_data, data),
         :ok <- write_byte(i2c_ref, @cmd_block_data_checksum, new_checksum) do
      :ok
    end
  end

  @spec read_data_memory(i2c_bus(), integer(), integer(), integer(), integer()) ::
          {:ok, binary()} | {:error, term()}
  def read_data_memory(i2c_ref, class, block, offset, length) do
    with :ok <- write_byte(i2c_ref, @cmd_block_data_control, 0),
         :ok <- write_byte(i2c_ref, @cmd_data_class, class),
         :ok <- write_byte(i2c_ref, @cmd_data_block, block) do
      Process.sleep(50)
      read_block_data(i2c_ref, offset, length)
    end
  end

  @spec read_block_data(i2c_bus(), integer(), integer()) :: {:ok, binary()} | {:error, term()}
  defp read_block_data(i2c_ref, offset, length) do
    I2C.write_read(i2c_ref, @i2c_address, <<@cmd_block_data_start + offset>>, length)
  end

  @spec write_block_data(i2c_bus(), integer(), binary()) :: :ok | {:error, term()}
  defp write_block_data(i2c_ref, offset, data) do
    I2C.write(i2c_ref, @i2c_address, <<@cmd_block_data_start + offset, data::binary>>)
  end

  @spec calculate_new_checksum(integer(), binary(), binary()) :: integer()
  defp calculate_new_checksum(old_checksum, old_data, new_data) do
    old_sum = Enum.sum(:binary.bin_to_list(old_data))
    new_sum = Enum.sum(:binary.bin_to_list(new_data))

    temp = Integer.mod(255 - old_checksum - old_sum, 256)
    255 - Integer.mod(temp + new_sum, 256)
  end

  defp chem_id_to_cmd(:chemistry_a), do: @control_chem_a
  defp chem_id_to_cmd(:chemistry_b), do: @control_chem_b
  defp chem_id_to_cmd(:chemistry_c), do: @control_chem_c

  # Helper to convert unsigned 16-bit value to signed
  defp value_to_signed16(value) when value > 32767, do: value - 65536
  defp value_to_signed16(value), do: value
end
