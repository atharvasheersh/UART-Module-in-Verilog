// -----------------------------------------------------------------------------
// Module: rx_fsm
//
// Purpose:
//   Generates timing pulses ("clock-enable ticks") for the UART.
//   - tx_bit_tick: 1× baud-rate tick used by the TX FSM to send bits
//   - rx_sample_tick: 16× baud-rate tick used by the RX FSM to oversample,
//     majority-vote, and validate start/stop
//
// Scope & Features alignment:
//   • Supports standard UART framing of 8 data bits, no parity, 1 stop bit (8-N-1).
//     Parity can still be added at a higher level, but base mode is 8-N-1.
//   • Baud is configurable by writing divider values. This allows a wide
//     baud range (e.g. ~9,600 up to ~1,000,000 bits/s) without changing RTL.
//   • Clean interface to CTRL/STATUS: system logic (or software) can program
//     rx_divider and tx_divider like CSR fields.
//   • Synchronous active-low reset.
//
// I/O:
//   clk_50mhz        : system clock
//   rst_n            : active-low synchronous reset
//   rx_divider[15:0] : cycles-per-sample for RX (16× baud sampling tick)
//   tx_divider[15:0] : cycles-per-bit    for TX (1× baud bit tick)
//   rx_sample_tick   : 1-cycle pulse at oversample rate
//   tx_bit_tick      : 1-cycle pulse at baud rate
// -----------------------------------------------------------------------------
module rx_fsm (
    input  wire        clk_50mhz,
    input  wire        rst_n,
    input  wire [15:0] rx_divider,
    input  wire [15:0] tx_divider,
    output reg         rx_sample_tick,
    output reg         tx_bit_tick
);

    reg [15:0] rx_count;
    reg [15:0] tx_count;

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

    always @(posedge clk_50mhz) begin
        if (!rst_n) begin
            tx_count     <= 16'd0;
            tx_bit_tick  <= 1'b0;
        end 
        else begin
            if (tx_count == tx_divider) begin
                tx_count     <= 16'd0;
                tx_bit_tick  <= 1'b1;
            end
        else begin
                tx_count     <= tx_count + 16'd1;
                tx_bit_tick  <= 1'b0;
            end
        end
    end

endmodule


