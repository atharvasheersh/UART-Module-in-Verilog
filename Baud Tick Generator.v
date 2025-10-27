// -----------------------------------------------------------------------------
// Module: uart_baud_gen
//
// Role in UART:
//   This block generates timing pulses ("tick" enables) for both the UART
//   Transmitter (TX) and Receiver (RX). The UART overall targets an 8 data bit,
//   no parity, 1 stop bit frame format (8-N-1). Optional parity can still be
//   supported in the higher-level CTRL/CSR logic by enabling parity bits, but
//   by default this design is 8-N-1.
//
// Inputs:
//   clk_50mhz        : main system clock (example: 50 MHz)
//   rst_n            : active-low synchronous reset
//   rx_divider[15:0] : cycles-per-sample for RX oversampling (16× baud)
//   tx_divider[15:0] : cycles-per-bit   for TX bit rate    (1× baud)
//
// Outputs:
//   rx_sample_tick   : 1-clock-cycle pulse at 16× baud, for RX FSM sampling
//   tx_bit_tick      : 1-clock-cycle pulse at 1× baud,  for TX FSM shifting
//
// Internal behavior:
//   - Two wraparound counters (rx_count, tx_count).
//   - When a counter reaches its programmed divider value, it:
//        * emits a single-cycle tick
//        * resets back to 0
//   - Counters are fixed 16-bit wide to match the divider inputs. This avoids
//     $clog2() / variable-width logic so it works in older Verilog toolflows.
// -----------------------------------------------------------------------------
module uart_baud_gen (
    input  wire        clk_50mhz,
    input  wire        rst_n,
    input  wire [15:0] rx_divider,
    input  wire [15:0] tx_divider,
    output reg         rx_sample_tick,
    output reg         tx_bit_tick
);

    reg [15:0] rx_count;
    reg [15:0] tx_count;

    // RX oversample tick generator (e.g. 16× baud)
    always @(posedge clk_50mhz) begin
        if (!rst_n) begin
            rx_count       <= 16'd0;
            rx_sample_tick <= 1'b0;
        end else begin
            if (rx_count == rx_divider) begin
                rx_count       <= 16'd0;
                rx_sample_tick <= 1'b1; 
            end else begin
                rx_count       <= rx_count + 16'd1;
                rx_sample_tick <= 1'b0;
            end
        end
    end

    // TX bit tick generator (1× baud)
    always @(posedge clk_50mhz) begin
        if (!rst_n) begin
            tx_count     <= 16'd0;
            tx_bit_tick  <= 1'b0;
        end else begin
            if (tx_count == tx_divider) begin
                tx_count     <= 16'd0;
                tx_bit_tick  <= 1'b1;    
            end else begin
                tx_count     <= tx_count + 16'd1;
                tx_bit_tick  <= 1'b0;
            end
        end
    end

endmodule
