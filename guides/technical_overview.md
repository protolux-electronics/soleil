# Technical Overview

This page provides a detailed overview of the hardware components that comprise Soleil. For a high-level summary, refer to the block diagram below:

![Block diagram of Soleil hardware](https://github.com/protolux-electronics/soleil_hardware/raw/main/docs/images/block_diagram.png)

To understand how Soleil manages power, we will trace the flow of electricity from its sources to its consumers.
## Battery Fuel Gauge

The primary power source for Soleil is the battery, which operates at a voltage between 3.2V and 4.2V, depending on its state of charge. However, the relationship between voltage and the battery's energy storage is non-linear. To accurately estimate the battery's state of charge, Soleil uses the [BQ27427](https://www.ti.com/product/BQ27427) battery fuel gauge chip. This chip measures the current flowing through it using internal circuitry and calculates the battery's state of charge accordingly. 

The BQ27427 communicates with the Raspberry Pi via an I2C interface, allowing it to read and write to the chip’s registers programmatically. Through the `Soleil.BQ27427` low-level driver module, users can configure battery parameters, set low-battery alarms, and perform additional tasks.
## Battery Charger

On the other side of the battery fuel gauge is the [BQ25185](https://www.ti.com/product/BQ25185) battery charger IC. This charger features internal power path management, meaning it can simultaneously power the system load (the Raspberry Pi) and charge the battery when a power source is connected to the `V_IN` pin. 

While the chip supports various lithium battery chemistries, it is configured to charge standard LiPo batteries to 4.2V at a rate of 500mA. The `V_IN` pin can draw a maximum of 1A to handle both charging and powering the system. If the system load requires more than 1A, the charger dynamically supplements the power supply by drawing from both the input power source and the battery. The `V_SYS` output from the charger powers several downstream components, including the 5V boost converter, the low-power load switch, and the wakeup sources.
## Boost Converter

Since the Raspberry Pi requires 5V to operate and the regulated `V_SYS` voltage peaks at approximately 4V (depending on the battery's charge level), a voltage boost is necessary. The [MP3423](https://www.monolithicpower.com/en/mp3423.html) boost converter fulfills this role by increasing `V_SYS` to a steady 5V output. Additionally, the converter's `EN` pin allows the 5V output to be enabled or disabled, which is crucial for entering low-power mode via the load switch.
## Low-Power Load Switch

The [XC6192](https://product.torexsemi.com/en/series/xc6192) low-power load switch is the central control component of Soleil. It features multiple input and output pins that govern the system's power state. 

- The `5V_EN` output pin controls the boost converter (and, by extension, the Raspberry Pi). When `5V_EN` is low, the switch enters a low-power state to conserve battery life.  
- The `~POWER_ON` input pin (active-low) triggers `5V_EN` to enable the 5V output when pulled low. By default, this pin is pulled high and is activated by wake-up sources.  
- The `POWER_OFF` input pin (active-high) disables `5V_EN` when pulled high. This pin is managed by the Raspberry Pi, which sets it high during shutdown to cut off the 5V supply.
## Wakeup Sources

The wake-up sources that control the `~POWER_ON` pin include a push button, the [DRV5032](https://www.ti.com/product/DRV5032) hall-effect switch, and the [MCP7940](https://www.microchip.com/en-us/product/mcp7940n) real-time clock. 

- When inactive, these sources allow `~POWER_ON` to remain at its default high voltage.  
- When triggered, they pull the pin low, enabling the 5V boost converter.  
  - The DRV5032 activates when a magnet is detected within its range.  
  - The MCP7940 real-time clock triggers upon an alarm event.  

The MCP7940 also connects to the Raspberry Pi via I2C, allowing configuration and monitoring through the `Soleil.MCP7940` driver module.
## Input Sources

Soleil supports two power input sources:  
- 5V via a USB-C connector.  
- 6–16V via a DC input on a JST PH connector.  

The [LM66200](https://www.ti.com/product/LM66200) power multiplexer manages these inputs, ensuring that only the higher voltage source is used while blocking reverse current to the lower-voltage source. The selected input provides power to the battery charger via the `V_IN` pin.
## Source Files

The source files for Soleil are available in the [GitHub repository](https://github.com/protolux-electronics/soleil_hardware). The project was designed using [KiCad](https://kicad.org), an open-source electronics design software. These files are fully customizable to meet your project requirements.

A PDF of the schematic is also available for reference or [download](https://raw.githubusercontent.com/protolux-electronics/soleil_hardware/main/outputs/soleil.pdf):

<iframe src="https://nbviewer.org/github/protolux-electronics/soleil_hardware/blob/main/outputs/soleil.pdf" width="3508" height="2480" style="border:none; width: 100%;"></iframe>
