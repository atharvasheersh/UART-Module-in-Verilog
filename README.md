# UART-Module-in-Verilog

Digital System Design (BECE102L) Course Project  
Authors: Atharva Sheersh Pandey, Aayush Jaiswal, and Satyam Bhalotia  
Guided by: Prof. Naveen Mishra

---

## Overview

This project implements a basic UART (Universal Asynchronous Receiver/Transmitter) in synthesizable Verilog, along with a simulation testbench. The design targets a standard **8-N-1** frame format:
- 8 data bits  
- No parity  
- 1 stop bit  

The focus in this version is on transmit (TX) functionality and baud-rate control. The receive (RX) path is defined and planned but not fully integrated in the top module.

---

## Module Hierarchy

1. **uart_top**  
   Integrates all submodules and exposes the external interface.

2. **uart_baud_gen**  
   Generates timing pulses based on programmable dividers:
   - `tx_bit_tick`: 1× baud tick for transmitting bits  
   - `rx_sample_tick`: 16× baud tick reserved for receiver oversampling

3. **tx_fsm**  
   UART transmitter state machine.  
   - Loads an 8-bit value and sends a full 8-N-1 frame (start bit, data LSB-first, stop bit) on `tx_line`  
   - Raises `tx_busy` while transmission is in progress

4. **uart_tb**  
   Testbench that drives clock/reset, sets baud dividers, sends a few bytes, and ends with `$finish`.

---

## Interface Signals

**Clock / Reset**
- `clk_50mhz`: System clock
- `rst_n`: Active-low reset

**Transmitter Interface**
- `tx_start`: Start transmission
- `tx_data_in[7:0]`: Data byte to send
- `tx_busy`: High while TX is active
- `tx_line`: Serial UART TX output (idle = high)

**Baud Control**
- `tx_divider[15:0]`, `rx_divider[15:0]`: Divider values that set the baud rate and oversampling rate

**Planned Receiver Interface**
- `rx`: Serial data in
- `rx_ready`: Byte received and valid
- `rx_data[7:0]`: Received data
- `rx_error`: Framing/parity error

---

## Simulation

To simulate:
1. Compile `uart_baud_gen`, `tx_fsm`, `uart_top`, and `uart_tb`.
2. Run `uart_tb` in ModelSim / Questa (or any Verilog simulator).
3. Observe:
   - `tx_start` is pulsed with test bytes
   - `tx_busy` goes high during transmission
   - `tx_line` outputs the serialized UART frame
4. Simulation ends with `$finish`.

---

## Notes

- Baud rate is configurable at runtime using divider inputs.
- The design is modular and synthesizable.
- RX path (oversampling, majority voting, stop-bit check) is part of the documented architecture and can be added on top of this base.
