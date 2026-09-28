module uart_tx #(
    parameter CLK_HZ = 25_200_000,
    parameter BAUD   = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data,
    input  wire       start,
    output reg        tx,
    output wire       busy
);
    localparam integer CLKS_PER_BIT = (CLK_HZ + BAUD/2) / BAUD;

    reg [15:0] cnt;
    reg [3:0]  bit_idx;
    reg [9:0]  shreg;
    reg        active;

    assign busy = active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx      <= 1'b1;
            active  <= 1'b0;
            cnt     <= 16'd0;
            bit_idx <= 4'd0;
            shreg   <= 10'h3FF;
        end else if (!active) begin
            tx <= 1'b1;
            if (start) begin
                shreg   <= {1'b1, data, 1'b0};
                active  <= 1'b1;
                cnt     <= 16'd0;
                bit_idx <= 4'd0;
                tx      <= 1'b0;
            end
        end else begin
            if (cnt == CLKS_PER_BIT - 1) begin
                cnt <= 16'd0;
                if (bit_idx == 4'd9) begin
                    active <= 1'b0;
                    tx     <= 1'b1;
                end else begin
                    bit_idx <= bit_idx + 4'd1;
                    tx      <= shreg[bit_idx + 4'd1];
                end
            end else begin
                cnt <= cnt + 16'd1;
            end
        end
    end
endmodule