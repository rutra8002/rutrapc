module rutragpu (
    input wire clk,
    input wire reset,
    input wire in_valid,
    input wire in_is_char,
    input wire [7:0] in_data,
    output wire consumed,
    output reg present_pulse,

    input  wire [5:0] vid_x,
    input  wire [5:0] vid_y,
    output wire       vid_pixel
);
    localparam [7:0] CMD_SET_X = 8'hF0;
    localparam [7:0] CMD_SET_Y = 8'hF1;
    localparam [7:0] CMD_PLOT = 8'hF2;
    localparam [7:0] CMD_CLEAR = 8'hF3;
    localparam [7:0] CMD_PRESENT = 8'hF4;

    localparam [2:0] WAIT_COMMAND = 3'd0;
    localparam [2:0] WAIT_X       = 3'd1;
    localparam [2:0] WAIT_Y       = 3'd2;
    localparam [2:0] WAIT_PLOT    = 3'd3;
    localparam [2:0] CLEARING     = 3'd4; 

    localparam FB_SIZE = 3072;              // 64 x 48

    reg [2:0]  state;
    reg [5:0]  cursor_x;
    reg [5:0]  cursor_y;
    reg [11:0] clear_addr;
    wire is_command;

    assign is_command = (in_data == CMD_SET_X) ||
                        (in_data == CMD_SET_Y) ||
                        (in_data == CMD_PLOT) ||
                        (in_data == CMD_CLEAR) ||
                        (in_data == CMD_PRESENT);

    assign consumed = in_valid && in_is_char && (
        ((state == WAIT_COMMAND) && is_command) ||
        (state == WAIT_X) ||
        (state == WAIT_Y) ||
        (state == WAIT_PLOT)
    );

    wire        wr_en   = (state == CLEARING) ||
                          (state == WAIT_PLOT && in_valid && in_is_char);
    wire [11:0] wr_addr = (state == CLEARING) ? clear_addr : {cursor_y, cursor_x};
    wire        wr_data = (state == CLEARING) ? 1'b0 : (in_data != 8'd0);

    Gowin_SDPB u_framebuffer (
        .clka   (clk),
        .cea    (wr_en),
        .reseta (reset),
        .ada    (wr_addr),
        .din    (wr_data),

        .clkb   (clk),
        .ceb    (1'b1),
        .resetb (reset),
        .oce    (1'b1),
        .adb    ({vid_y, vid_x}),
        .dout   (vid_pixel)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= CLEARING;
            cursor_x    <= 6'd0;
            cursor_y    <= 6'd0;
            present_pulse <= 1'b0;
            clear_addr  <= 12'd0;
        end else begin
            present_pulse <= 1'b0;

            case (state)
                CLEARING: begin
                    if (clear_addr == FB_SIZE - 1) begin
                        clear_addr <= 12'd0;
                        state      <= WAIT_COMMAND;
                    end else begin
                        clear_addr <= clear_addr + 12'd1;
                    end
                end
                WAIT_COMMAND: begin
                    if (in_valid && in_is_char) begin
                        case (in_data)
                            CMD_SET_X: state <= WAIT_X;
                            CMD_SET_Y: state <= WAIT_Y;
                            CMD_PLOT:  state <= WAIT_PLOT;
                            CMD_CLEAR: begin
                                clear_addr <= 12'd0;
                                state      <= CLEARING;
                            end
                            CMD_PRESENT: present_pulse <= 1'b1;
                            default: begin
                                // Not a GPU command; let normal output path handle it.
                            end
                        endcase
                    end
                end
                WAIT_X: begin
                    if (in_valid && in_is_char) begin
                        cursor_x <= in_data[5:0];
                        state    <= WAIT_COMMAND;
                    end
                end
                WAIT_Y: begin
                    if (in_valid && in_is_char) begin
                        cursor_y <= in_data[5:0];
                        state    <= WAIT_COMMAND;
                    end
                end
                WAIT_PLOT: begin
                    if (in_valid && in_is_char) begin
                        state <= WAIT_COMMAND;
                    end
                end
            endcase
        end
    end
endmodule