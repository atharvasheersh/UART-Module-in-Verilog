# UART-Module-in-Verilog

Digital System Design (BECE102L) Project  
Author: Atharva Sheersh Pandey, Aayush Jaiswal, Satyam Bhalotia under the guidance of Prof. Naveen Mishra

## Summary

This project implements a simple UART communication path in synthesizable Verilog, along with a basic simulation testbench. The focus is on the UART transmitter, baud-rate generation, and integration.

The design targets the common UART frame format **8-N-1**:
- 8 data bits
- No parity
- 1 stop bit

The modules are written in plain RTL (no IP cores), reset to known states, and are suitable for synthesis.

---

## Features

- **Configurable baud rate** via programmable divider inputs.
- **8-N-1 framing**: start bit (0), 8 data bits (LSB first), stop bit (1).
- **Clock-enable tick generation** instead of relying directly on the raw system clock.
- **Transmitter busy flag** (`tx_busy`) for handshake/status.
- **Synchronous system integration** with a clean top-level module.
- **Testbench** that applies reset, drives data, and ends with `$finish`.

The RX-side oversampling concept (16× sampling with majority vote) is described in the documentation and supported by the tick generator interface, but the final integrated top module in this repo mainly demonstrates TX.

---

## Repository Contents

### `uart_baud_gen` (in `Baud Tick Generator.v`)
Generates timing pulses used by the UART logic.

Outputs:
- `tx_bit_tick`: 1-cycle-wide pulse at the actual baud rate. This controls when the transmitter is allowed to shift out the next bit.
- `rx_sample_tick`: 1-cycle-wide pulse at 16× the baud rate. This is intended for the receiver FSM (for oversampling and start/stop validation).

Inputs:
- `clk_50mhz`: main system clock (e.g. 50 MHz in lab setup)
- `rst_n`: active-low reset
- `tx_divider[15:0]`: number of system clock cycles per transmitted bit
- `rx_divider[15:0]`: number of system clock cycles per oversample tick

Internally it uses two counters. When each counter reaches its programmed divider, it emits a pulse and wraps back to zero. Because `tx_divider` and `rx_divider` are inputs, the baud rate is configurable without editing RTL.

This matches the spec item: “Configurable baud via clock-enable tick.”

---

### `uart_tx_fsm` (in `TX_FSM`)
Implements the UART transmitter state machine.

Behavior:
- Waits for a request (`tx_start`) along with an 8-bit value (`tx_data_in`).
- Builds a full 10-bit UART frame in a shift register:
  `{ stop_bit(1), data[7:0], start_bit(0) }`
- Drives the serial line `tx_line` one bit at a time.
- Uses `tx_bit_tick` (from `uart_baud_gen`) so each bit is held for one baud period.
- Sends LSB first, as required by UART.

Key signals:
- `tx_line`: the serial TX output line. It idles high.
- `tx_busy`: goes high while the frame is being sent, returns low once done. This is equivalent to a STATUS bit for software or higher-level logic.
- `tx_start`: acts like a CTRL strobe to load and transmit a new byte.

This module implements the 8-N-1 frame format:
- Start bit = 0
- 8 data bits (LSB first)
- Stop bit = 1

---

### `rx_fsm` (in `RX_FSM.v`)
In the current integration, this file name was used during development to refer to a “tick generator / timing enable” block. In the final structure we use `uart_baud_gen` for that purpose. The intended role of an RX FSM in a complete UART is:
- Detect falling edge of the start bit.
- Sample at 16× the baud using `rx_sample_tick`.
- Majority-vote the sampled values to tolerate small baud mismatch and noise.
- Reconstruct the received byte and verify that the stop bit is high (framing check).

That RX capture/majority-vote logic is described in the project report (`UART Communication Module in Verilog.pdf`). It is not fully wired into `uart_top` in this revision, but the baud generator already exposes the required `rx_sample_tick` for it.

---

### `uart_top`
Integration wrapper.

- Instantiates:
  - `uart_baud_gen`
  - `uart_tx_fsm`
- Connects `tx_bit_tick` from `uart_baud_gen` into `uart_tx_fsm`.
- Exposes a simple external interface:
  - Inputs:
    - `clk_50mhz`
    - `rst_n`
    - `tx_start`
    - `tx_data_in[7:0]`
    - `tx_divider`, `rx_divider` (baud configuration)
  - Outputs:
    - `tx_line`
    - `tx_busy`

This is effectively the “UART peripheral” from the system’s point of view: you give it a byte, tell it to send, and it drives a serial TX line at the configured baud.

---

### `uart_tb`
Non-synthesizable Verilog testbench for simulation.

What it does:
1. Generates a clock using `always #10 clk = ~clk`.
2. Holds reset low, then releases it.
3. Programs `rx_divider` and `tx_divider`.
4. Sends one or more bytes by driving `tx_data_in` and pulsing `tx_start`.
5. Lets the UART transmit.
6. Calls `$finish` to stop the simulation.

This testbench is intentionally simple:
- No `$display`
- No assertions
- No scoreboard
- Purely for opening the wave window and inspecting signals like `tx_line`, `tx_busy`, and the internal tick pulses.

If the simulator shows time in picoseconds instead of nanoseconds and the clock looks “too fast,” you can add this to the top of the testbench:
```verilog
`timescale 1ns/1ps
