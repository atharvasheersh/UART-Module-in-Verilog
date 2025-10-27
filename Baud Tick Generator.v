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
//   - $clog2() is used to auto-size the counters so they are only as wide as
//     needed for the chosen divider.
//
// -----------------------------------------------------------------------------
module uart_baud_gen (
    input  wire clk_50mhz,
    input  wire rst_n,
    input  wire [15:0] rx_divider,
    input  wire [15:0] tx_divider,
    output wire rx_sample_tick,
    output wire tx_bit_tick
);

    // Compute counter widths from the divider values.
    // We +1 here in case divider is 0; avoids zero-width regs in corner cases.
    localparam integer RX_CNT_WIDTH = $clog2(16'hFFFF) + 1;
    localparam integer TX_CNT_WIDTH = $clog2(16'hFFFF) + 1;

    reg [RX_CNT_WIDTH-1:0] rx_count = {RX_CNT_WIDTH{1'b0}};
    reg [TX_CNT_WIDTH-1:0] tx_count = {TX_CNT_WIDTH{1'b0}};

    assign rx_sample_tick = (rx_count == {RX_CNT_WIDTH{1'b0}});
    assign tx_bit_tick    = (tx_count == {TX_CNT_WIDTH{1'b0}});

    always @(posedge clk_50mhz) begin
        if (!rst_n) begin
            rx_count <= {RX_CNT_WIDTH{1'b0}};
        end else if (rx_count == rx_divider[RX_CNT_WIDTH-1:0]) begin
            rx_count <= {RX_CNT_WIDTH{1'b0}};
        end else begin
            rx_count <= rx_count + 1'b1;
        end
    end

    always @(posedge clk_50mhz) begin
        if (!rst_n) begin
            tx_count <= {TX_CNT_WIDTH{1'b0}};
        end
        else if (tx_count == tx_divider[TX_CNT_WIDTH-1:0]) begin
            tx_count <= {TX_CNT_WIDTH{1'b0}};
        end
        else begin
            tx_count <= tx_count + 1'b1;
        end
    end
endmodule
