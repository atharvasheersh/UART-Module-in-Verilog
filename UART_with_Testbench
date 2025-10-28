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

module uart_top (
    input  wire        clk_50mhz,
    input  wire        rst_n,
    input  wire [15:0] rx_divider,
    input  wire [15:0] tx_divider,
    input  wire        tx_start,
    input  wire [7:0]  tx_data_in,
    output wire        tx_line,
    output wire        tx_busy
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
endmodule

module uart_tb;
    reg         clk_50mhz;
    reg         rst_n;
    reg [15:0]  rx_divider;
    reg [15:0]  tx_divider;
    reg         tx_start;
    reg [7:0]   tx_data_in;

    wire        tx_line;
    wire        tx_busy;

    uart_top dut (
        .clk_50mhz(clk_50mhz),
        .rst_n(rst_n),
        .rx_divider(rx_divider),
        .tx_divider(tx_divider),
        .tx_start(tx_start),
        .tx_data_in(tx_data_in),
        .tx_line(tx_line),
        .tx_busy(tx_busy)
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

        #100;
        rst_n = 1'b1;
        #100;

        tx_data_in = 8'hA5;
        tx_start   = 1'b1;
        #20;
        tx_start   = 1'b0;

        #200;

        tx_data_in = 8'h3C;
        tx_start   = 1'b1;
        #20;
        tx_start   = 1'b0;

        #2000;
        $finish;
    end
endmodule


