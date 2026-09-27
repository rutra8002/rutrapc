module rutragpu (
    input wire clk,
    input wire reset,

    input  wire [3:0] cmd,
    input  wire [7:0] arg,
    input  wire       start,
    output reg        done,

    output reg present_pulse,

    input  wire [5:0] vid_x,
    input  wire [5:0] vid_y,
    output wire       vid_pixel
);
    localparam [3:0] CMD_SET_X   = 4'd0;
    localparam [3:0] CMD_SET_Y   = 4'd1;
    localparam [3:0] CMD_PLOT    = 4'd2;
    localparam [3:0] CMD_CLEAR   = 4'd3;
    localparam [3:0] CMD_PRESENT = 4'd4;

    localparam WAIT     = 1'b0;
    localparam CLEARING = 1'b1;

    localparam FB_SIZE = 3072;              // 64 x 48

    reg        state;
    reg [5:0]  cursor_x;
    reg [5:0]  cursor_y;
    reg [11:0] clear_addr;

    wire        is_plot_now = (state == WAIT) && start && (cmd == CMD_PLOT);
    wire        wr_en   = (state == CLEARING) || is_plot_now;
    wire [11:0] wr_addr = (state == CLEARING) ? clear_addr : {cursor_y, cursor_x};
    wire        wr_data = (state == CLEARING) ? 1'b0 : (arg != 8'd0);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= CLEARING; 
            cursor_x      <= 6'd0;
            cursor_y      <= 6'd0;
            clear_addr    <= 12'd0;
            done          <= 1'b0;
            present_pulse <= 1'b0;
        end else begin
            done          <= 1'b0;
            present_pulse <= 1'b0;

            case (state)
                CLEARING: begin
                    if (clear_addr == FB_SIZE - 1) begin
                        clear_addr <= 12'd0;
                        state      <= WAIT;
                        done       <= 1'b1;
                    end else begin
                        clear_addr <= clear_addr + 12'd1;
                    end
                end
                WAIT: begin
                    if (start) begin
                        case (cmd)
                            CMD_SET_X: begin
                                cursor_x <= arg[5:0];
                                done     <= 1'b1;
                            end
                            CMD_SET_Y: begin
                                cursor_y <= arg[5:0];
                                done     <= 1'b1;
                            end
                            CMD_PLOT: begin
                                done <= 1'b1; 
                            end
                            CMD_CLEAR: begin
                                clear_addr <= 12'd0;
                                state      <= CLEARING; 
                            end
                            CMD_PRESENT: begin
                                present_pulse <= 1'b1;
                                done          <= 1'b1;
                            end
                            default: done <= 1'b1;
                        endcase
                    end
                end
            endcase
        end
    end

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

endmodule