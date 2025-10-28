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

module tx_fsm (
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
        end else begin
            if (tx_bit_tick) begin
                if (!tx_busy) begin
                    if (tx_start) begin
                        shift_reg <= {1'b1, tx_data_in, 1'b0};
                        tx_busy   <= 1'b1;
                        bit_ctr   <= 4'd0;
                    end
                end else begin
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

module rx_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_sample_tick,
    input  wire       rx_line,
    output reg [7:0]  rx_data_out,
    output reg        rx_ready,
    output reg        rx_error
);
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [3:0] bit_ctr;
    reg [3:0] sample_ctr;

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
                        if (rx_sync2 == 1'b0) begin
                            state <= START;
                        end
                    end

                    START: begin
                        sample_ctr <= sample_ctr + 4'd1;
                        if (sample_ctr == 4'd7) begin
                            if (rx_sync2 == 1'b0) begin
                                state      <= DATA;
                                sample_ctr <= 4'd0;
                                bit_ctr    <= 4'd0;
                            end else begin
                                state <= IDLE;
                            end
                        end
                    end

                    DATA: begin
                        sample_ctr <= sample_ctr + 4'd1;
                        if (sample_ctr == 4'd7) begin
                            shift_reg  <= {rx_sync2, shift_reg[7:1]};
                            bit_ctr    <= bit_ctr + 4'd1;
                            sample_ctr <= 4'd0;
                            if (bit_ctr == 4'd7) begin
                                state <= STOP;
                            end
                        end
                    end

                    STOP: begin
                        sample_ctr <= sample_ctr + 4'd1;
                        if (sample_ctr == 4'd7) begin
                            if (rx_sync2 == 1'b1) begin
                                rx_data_out <= shift_reg;
                                rx_ready    <= 1'b1;
                            end else begin
                                rx_error    <= 1'b1;
                            end
                            state      <= IDLE;
                            sample_ctr <= 4'd0;
                        end
                    end

                    default: begin
                        state <= IDLE;
                    end
                endcase
            end
        end
    end
endmodule

module uart_top (
    input  wire        clk_50mhz,
    input  wire        rst_n,
    input  wire [15:0] rx_divider,
    input  wire [15:0] tx_divider,
    input  wire        tx_start,
    input  wire [7:0]  tx_data_in,
    input  wire        rx_line,
    output wire        tx_line,
    output wire        tx_busy,
    output wire [7:0]  rx_data_out,
    output wire        rx_ready,
    output wire        rx_error
);
    wire rx_sample_tick;
    wire tx_bit_tick;

    uart_baud_gen baud_inst (
        .clk_50mhz(clk_50mhz),
        .rst_n(rst_n),
        .rx_divider(rx_divider),
        .tx_divider(tx_divider),
        .rx_sample_tick(rx_sample_tick),
        .tx_bit_tick(tx_bit_tick)
    );

    tx_fsm tx_inst (
        .clk(clk_50mhz),
        .rst_n(rst_n),
        .tx_bit_tick(tx_bit_tick),
        .tx_start(tx_start),
        .tx_data_in(tx_data_in),
        .tx_line(tx_line),
        .tx_busy(tx_busy)
    );

    rx_fsm rx_inst (
        .clk(clk_50mhz),
        .rst_n(rst_n),
        .rx_sample_tick(rx_sample_tick),
        .rx_line(rx_line),
        .rx_data_out(rx_data_out),
        .rx_ready(rx_ready),
        .rx_error(rx_error)
    );
endmodule

module uart_tb;
    reg         clk_50mhz;
    reg         rst_n;
    reg [15:0]  rx_divider;
    reg [15:0]  tx_divider;
    reg         tx_start;
    reg [7:0]   tx_data_in;
    reg         rx_line;

    wire        tx_line;
    wire        tx_busy;
    wire [7:0]  rx_data_out;
    wire        rx_ready;
    wire        rx_error;

    uart_top dut (
        .clk_50mhz(clk_50mhz),
        .rst_n(rst_n),
        .rx_divider(rx_divider),
        .tx_divider(tx_divider),
        .tx_start(tx_start),
        .tx_data_in(tx_data_in),
        .rx_line(rx_line),
        .tx_line(tx_line),
        .tx_busy(tx_busy),
        .rx_data_out(rx_data_out),
        .rx_ready(rx_ready),
        .rx_error(rx_error)
    );

    always begin
        #10 clk_50mhz = ~clk_50mhz;
    end

    initial begin
        clk_50mhz  = 1'b0;
        rst_n      = 1'b0;
        rx_divider = 16'd27;
        tx_divider = 16'd434;
        tx_start   = 1'b0;
        tx_data_in = 8'h00;
        rx_line    = 1'b1; 

        #100;
        rst_n = 1'b1;
        #100;

        tx_data_in = 8'hA5;
        tx_start   = 1'b1;
        #20;
        tx_start   = 1'b0;

        // (rx_line would normally be driven by an external UART transmitter.
        // here we leave it idle or you could manually toggle it to emulate a frame)
        #200;
        tx_data_in = 8'h3C;
        tx_start   = 1'b1;
        #20;
        tx_start   = 1'b0;

        #2000;
        $finish;
    end
endmodule

