# UART-Module-in-Verilog

Digital System Design (BECE102L) Course Project  
Authors: Atharva Sheersh Pandey, Aayush Jaiswal, and Satyam Bhalotia  
Guided by: Prof. Naveen Mishra

---

## Overview

This project implements a synthesizable UART (Universal Asynchronous Receiver/Transmitter) core in Verilog.

Key features:
- Standard 8-N-1 UART framing (8 data bits, no parity, 1 stop bit)
- Programmable baud rate using divider inputs
- Transmit path (TX): parallel byte → serial line (`tx_line`)
- Receive path (RX): serial line (`rx_line`) → parallel byte
- Integrated top module and simulation testbench

The repository includes the baud generator, TX FSM, RX FSM, UART top, and testbench.

---

## Repository Structure

UART-Module-in-Verilog/  
├── Baud_Tick_Generator.v                 # Baud/tick generator module  
├── TX_FSM.v                              # UART transmitter state machine  
├── RX_FSM.v                              # UART receiver state machine  
├── UART_with_Testbench.v                 # UART top-level + testbench  
├── UART Communication Module in Verilog.pdf  # Project documentation / report  
├── LICENSE                               # Repository license  
└── README.md                             # This file  

---

## Module Descriptions

### 1. Baud Tick Generator (`Baud_Tick_Generator.v`)

Generates timing enable pulses for the UART logic.

Outputs:
- `tx_bit_tick`: One-cycle pulse per bit period (baud rate). TX shifts one bit on each pulse.
- `rx_sample_tick`: One-cycle pulse at ~16× baud. RX samples incoming data on this strobe.

Divider calculation:
- `tx_divider = (CLK_FREQ / BAUD_RATE) - 1`
- `rx_divider = (CLK_FREQ / (BAUD_RATE * 16)) - 1`

Example (50 MHz clock, 115200 baud):
- `tx_divider = 16'd433`
- `rx_divider = 16'd27`

Changing these divider values changes the baud rate without modifying RTL.

---

### 2. Transmitter (`TX_FSM.v`)

Implements the UART transmit state machine.

Behavior:
- Waits idle with the TX line high.
- On `tx_start`, loads a 10-bit frame `{stop_bit(1), data[7:0], start_bit(0)}`.
- On each `tx_bit_tick`, shifts out the next bit on `tx_line`, LSB first.
- Drives `tx_busy` high while transmitting so the sender knows not to queue another byte.

Key signals:
- Inputs: `tx_start`, `tx_data_in[7:0]`, `tx_bit_tick`
- Outputs: `tx_line`, `tx_busy`

---

### 3. Receiver (`RX_FSM.v`)

Implements the UART receive state machine.

Behavior:
- Detects the start bit (falling edge on `rx_line`).
- Samples the line in the middle of each bit using `rx_sample_tick` (16× baud).
- Reconstructs 8 data bits (LSB first).
- Checks the stop bit.
- On success:
  - Latches the byte into `rx_data_out[7:0]`
  - Pulses `rx_ready`
- On framing error (bad stop bit):
  - Pulses `rx_error`

Key signals:
- Inputs: `rx_line`, `rx_sample_tick`
- Outputs: `rx_data_out[7:0]`, `rx_ready`, `rx_error`

Includes a 2-flop synchronizer for `rx_line` to avoid metastability.

---

### 4. Complete System (`UART_with_Testbench.v`)

Contains:
- The integrated UART top module:
  - Instantiates the baud generator, TX FSM, and RX FSM
  - Exposes `tx_line`, `tx_busy`, `rx_data_out`, `rx_ready`, `rx_error`
  - Accepts `tx_divider` / `rx_divider` to program baud timing

- A simulation testbench (`uart_tb`):
  - Generates a clock
  - Applies reset
  - Sets divider values
  - Sends bytes using `tx_start` and `tx_data_in`
  - Optionally drives `rx_line` to emulate incoming UART traffic
  - Finishes simulation with `$finish`

This is the file you compile and run in a simulator.

---

## Quick Start

### Simulation with Icarus Verilog

1. Compile and simulate  
   `iverilog -o uart_sim UART_with_Testbench.v`  
   `vvp uart_sim`

2. (Optional) View waveforms with GTKWave (if you dump a VCD in the testbench)  
   `gtkwave uart_tb.vcd`

### Simulation with ModelSim / Questa

1. Compile  
   `vlog UART_with_Testbench.v`

2. Simulate  
   `vsim uart_tb`  
   `run -all`

In simulation, observe:
- `tx_line` toggling through start bit → data bits → stop bit  
- `tx_busy` asserted while transmitting  
- `rx_ready` pulsing when a byte is received  
- `rx_data_out` holding the received byte  
- `rx_error` pulsing if the stop bit was invalid  

---

## Important Notes

- UART frame format is fixed to 8-N-1 (1 start bit, 8 data bits LSB-first, 1 stop bit, no parity).
- Baud rate is set at runtime using `tx_divider` and `rx_divider` (no RTL edits required).
- Timing is controlled using single-cycle enable pulses (`tx_bit_tick`, `rx_sample_tick`) instead of generating new clocks.
- `tx_busy` tells you when the transmitter is active.
- `rx_ready` tells you when a valid byte has been received.
- `rx_error` flags a framing error (bad stop bit).
- The design is modular and synthesizable, so it can be dropped into a SoC / FPGA-style system as a UART peripheral.

**If you find this project helpful, please star ⭐ the repository.**
