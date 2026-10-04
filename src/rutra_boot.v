module rutra_boot #(
    parameter [7:0] MAGIC = 8'hB7
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] rx_data,
    input  wire       rx_valid,

    output wire       rom_we,
    output wire [7:0] rom_addr,
    output wire [15:0] rom_wdata,
    output wire       cpu_hold
);
    localparam [2:0] S_IDLE = 3'd0, S_LEN = 3'd1, S_HI = 3'd2, S_LO = 3'd3, S_RUN = 3'd4;

    reg [2:0] state;
    reg [8:0] remaining;
    reg [7:0] addr;
    reg [7:0] hi;
    reg       loaded = 1'b0;

    assign rom_we    = (state == S_LO) & rx_valid;
    assign rom_addr  = addr;
    assign rom_wdata = {hi, rx_data};
    assign cpu_hold  = (state != S_RUN);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= loaded ? S_RUN : S_IDLE;
            remaining <= 9'd0;
            addr      <= 8'd0;
            hi        <= 8'd0;
        end else if (rx_valid) begin
            case (state)
                S_IDLE, S_RUN: if (rx_data == MAGIC) state <= S_LEN;
                S_LEN: begin
                    remaining <= (rx_data == 8'd0) ? 9'd256 : {1'b0, rx_data};
                    addr      <= 8'd0;
                    state     <= S_HI;
                end
                S_HI: begin
                    hi    <= rx_data;
                    state <= S_LO;
                end
                S_LO: begin
                    addr      <= addr + 8'd1;
                    remaining <= remaining - 9'd1;
                    if (remaining == 9'd1) begin
                        loaded <= 1'b1;
                        state  <= S_RUN;
                    end else state <= S_HI;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule