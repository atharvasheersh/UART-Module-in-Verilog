// -----------------------------------------------------------------------------
// Module: uart_tx_fsm
//
// Role in UART:
//   This is the UART Transmitter finite state machine (TX FSM). It sends bytes
//   out on the serial TX line using standard UART framing: 1 start bit (0),
//   8 data bits LSB-first, and 1 stop bit (1). This is the classic 8-N-1 frame
//   format (8 data bits, No parity, 1 stop bit).
//
// Frame format it generates:
//   Idle(1) → Start(0) → data[0] ... data[7] (LSB first) → Stop(1).
//   The TX line idles HIGH, goes LOW for the start bit, shifts out all 8 bits
//   least-significant-bit first, then returns HIGH for the stop bit.
//
// Handshake / CSR view:
//   • tx_data_in[7:0] : the byte to transmit (like writing TXDATA register).
//   • tx_start        : request to start transmission (like a CTRL bit).
//   • tx_busy         : status flag that stays HIGH while a frame is being
//                       sent (this can be exposed in STATUS).
//   So this TX block can plug cleanly into a Control/Status Register interface.
//
// Timing / Baud rate:
//   • tx_bit_tick is a 1-cycle pulse at the programmed baud rate.
//   • The baud rate itself is generated externally by the baud generator using
//     a programmable divider, so the UART baud is configurable (for example
//     9.6 kbit/s up to ~1 Mbit/s) without changing this FSM.
//   • The TX FSM only advances to the next bit when tx_bit_tick is HIGH,
//     so each bit is held for exactly one baud period.
//
// Internal operation:
//   • shift_reg[9:0] holds the full 10-bit frame:
//         { stop_bit(1), data[7:0], start_bit(0) }
//     The least significant bit of shift_reg is always the next bit to drive
//     on the TX line. On each tx_bit_tick we output that bit, shift right,
//     and increment bit_ctr.
//   • bit_ctr[3:0] counts how many bits (0..9) we've sent.
//   • When bit_ctr reaches 9 (stop bit sent), tx_busy is cleared, meaning the
//     transmitter is idle and ready for the next byte.
//
// Reset / CDC notes:
//   • rst_n is active-low reset for this block. In the full design, an RX path
//     will separately use a 16× oversampling RX FSM with a 2-flip-flop
//     synchronizer on the incoming rx line to handle clock domain crossing and
//     do majority voting on sampled bits.
// -----------------------------------------------------------------------------
module uart_tx_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_bit_tick,
    input  wire       tx_start,
    input  wire [7:0] tx_data_in,
    output reg        tx_line,
    output reg        tx_busy
);

    reg [9:0] shift_reg;
    reg [3:0] bit_ctr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_line   <= 1'b1;
            tx_busy   <= 1'b0;
            shift_reg <= 10'd0;
            bit_ctr   <= 4'd0;
        end 
      else begin
            if (tx_bit_tick) begin
                if (!tx_busy) begin
                    if (tx_start) begin
                        shift_reg <= {1'b1, tx_data_in, 1'b0};
                        tx_busy   <= 1'b1;
                        bit_ctr   <= 4'd0;
                    end
                end 
      else begin
                    tx_line   <= shift_reg[0];
                    shift_reg <= shift_reg >> 1;
                    bit_ctr   <= bit_ctr + 4'd1;

                    if (bit_ctr == 4'd9) begin
                        tx_busy <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
