module uart_rx #(
    parameter CLK_HZ = 25_200_000,
    parameter BAUD   = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid
);
    localparam integer CLKS_PER_BIT = (CLK_HZ + BAUD/2) / BAUD;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;

    reg rx_s1, rx_s2;
    always @(posedge clk) begin
        rx_s1 <= rx;
        rx_s2 <= rx_s1;
    end

    localparam [1:0] S_IDLE = 2'd0, S_START = 2'd1, S_DATA = 2'd2, S_STOP = 2'd3;
    reg [1:0]  state;
    reg [15:0] cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  shreg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state   <= S_IDLE;
            cnt     <= 16'd0;
            bit_idx <= 3'd0;
            shreg   <= 8'd0;
            data    <= 8'd0;
            valid   <= 1'b0;
        end else begin
            valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    cnt <= 16'd0;
                    if (!rx_s2) state <= S_START;
                end
                S_START: begin
                    if (cnt == HALF_BIT - 1) begin
                        cnt <= 16'd0;
                        if (!rx_s2) begin bit_idx <= 3'd0; state <= S_DATA; end
                        else state <= S_IDLE;
                    end else cnt <= cnt + 16'd1;
                end
                S_DATA: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        cnt   <= 16'd0;
                        shreg <= {rx_s2, shreg[7:1]};
                        if (bit_idx == 3'd7) state <= S_STOP;
                        else bit_idx <= bit_idx + 3'd1;
                    end else cnt <= cnt + 16'd1;
                end
                S_STOP: begin
                    if (cnt == CLKS_PER_BIT - 1) begin
                        data  <= shreg;
                        valid <= 1'b1;
                        state <= S_IDLE;
                    end else cnt <= cnt + 16'd1;
                end
            endcase
        end
    end
endmodule