// -----------------------------------------------------------------------------
// Module: rx_fsm
//
// Role:
//   UART Receive Finite State Machine.
//   Reconstructs an incoming UART frame from the serial RX line using
//   oversampling. Assumes an external baud generator provides a 16×
//   oversample enable pulse (rx_sample_tick).
//
// Frame format assumed:
//   Start bit  (0)
//   8 data bits (LSB first)
//   Stop bit   (1)
//   => 8-N-1 (8 data bits, No parity, 1 stop bit)
//
// Operation summary:
//   1. IDLE:
//        Wait for the line to go low (potential start bit).
//   2. START:
//        Confirm it is a valid start bit by sampling near the middle.
//   3. DATA:
//        For each of the 8 data bits, sample in the middle of the bit period
//        and shift the sampled value into a shift register (LSB first).
//   4. STOP:
//        Sample the stop bit. If it is high, assert rx_ready for one cycle
//        and present the received byte on rx_data_out.
//        If it is low, assert rx_error for one cycle (framing error).
//
// Interface:
//   Inputs:
//     clk             : system clock
//     rst_n           : active-low asynchronous reset
//     rx_sample_tick  : 16× baud-rate sampling strobe (1-cycle pulse)
//     rx_line         : asynchronous serial RX input from UART line
//
//   Outputs:
//     rx_data_out[7:0]: received data byte (valid when rx_ready = 1)
//     rx_ready        : 1-cycle pulse indicating a new valid byte
//     rx_error        : 1-cycle pulse indicating framing error (bad stop bit)
//
// Notes:
//   - rx_line is synchronized internally (2-flop synchronizer) to avoid
//     metastability.
//   - Sampling is done at the middle of each bit using a sub-bit counter
//     (sample_ctr). Majority voting can be added later if desired.
// -----------------------------------------------------------------------------
module rx_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_sample_tick,
    input  wire       rx_line,
    output reg  [7:0] rx_data_out,
    output reg        rx_ready,
    output reg        rx_error
);
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  state;
    reg [7:0]  shift_reg;
    reg [3:0]  bit_ctr;
    reg [3:0]  sample_ctr;
    
    // Synchronizer for metastability protection
    reg rx_sync1, rx_sync2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx_line;
            rx_sync2 <= rx_sync1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            shift_reg   <= 8'd0;
            bit_ctr     <= 4'd0;
            sample_ctr  <= 4'd0;
            rx_data_out <= 8'd0;
            rx_ready    <= 1'b0;
            rx_error    <= 1'b0;
        end else begin
            rx_ready <= 1'b0;
            rx_error <= 1'b0;
            
            if (rx_sample_tick) begin
                case (state)
                    IDLE: begin
                        bit_ctr    <= 4'd0;
                        sample_ctr <= 4'd0;
                        if (rx_sync2 == 1'b0) begin  // start bit edge detect
                            state <= START;
                        end
                    end
                    
                    START: begin
                        sample_ctr <= sample_ctr + 4'd1;
                        // sample mid start bit (tick ~8/16)
                        if (sample_ctr == 4'd7) begin
                            if (rx_sync2 == 1'b0) begin
                                state      <= DATA;     // valid start
                                sample_ctr <= 4'd0;
                                bit_ctr    <= 4'd0;
                            end else begin
                                state <= IDLE;          // noise / glitch
                            end
                        end
                    end
                    
                    DATA: begin
                        sample_ctr <= sample_ctr + 4'd1;
                        // sample mid data bit
                        if (sample_ctr == 4'd7) begin
                            shift_reg  <= {rx_sync2, shift_reg[7:1]}; // LSB first
                            bit_ctr    <= bit_ctr + 4'd1;
                            sample_ctr <= 4'd0;
                            
                            if (bit_ctr == 4'd7) begin
                                state <= STOP;
                            end
                        end
                    end
                    
                    STOP: begin
                        sample_ctr <= sample_ctr + 4'd1;
                        // sample stop bit mid-bit
                        if (sample_ctr == 4'd7) begin
                            if (rx_sync2 == 1'b1) begin
                                rx_data_out <= shift_reg;
                                rx_ready    <= 1'b1;    // byte valid
                            end else begin
                                rx_error    <= 1'b1;    // framing error
                            end
                            state      <= IDLE;
                            sample_ctr <= 4'd0;
                        end
                    end
                    
                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule
