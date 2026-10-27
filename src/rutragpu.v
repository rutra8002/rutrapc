module rutragpu (
    input wire clk,
    input wire reset,

    input  wire [3:0] command,
    input  wire [15:0] argument,
    input  wire       command_start,
    output wire       command_ready,
    output reg        command_done,

    output reg present_frame_pulse,

    input  wire [7:0] video_x, 
    input  wire [7:0] video_y,
    output wire [7:0] video_pixel
);
    localparam [3:0] COMMAND_SET_X   = 4'd0;
    localparam [3:0] COMMAND_SET_Y   = 4'd1;
    localparam [3:0] COMMAND_PLOT    = 4'd2;
    localparam [3:0] COMMAND_CLEAR   = 4'd3;
    localparam [3:0] COMMAND_PRESENT = 4'd4;

    localparam STATE_WAIT_FOR_COMMAND     = 1'b0;
    localparam STATE_CLEARING_FRAMEBUFFER = 1'b1;

    localparam FRAMEBUFFER_WIDTH    = 160;
    localparam FRAMEBUFFER_HEIGHT    = 120;
    localparam FRAMEBUFFER_PIXEL_COUNT = 19200;

    reg        gpu_state;
    reg [15:0] cursor_x;
    reg [15:0] cursor_y;
    reg [14:0] clear_address;
    reg [7:0]  clear_color;

    assign command_ready = (gpu_state == STATE_WAIT_FOR_COMMAND);

    wire        cursor_in_bounds   = (cursor_x < FRAMEBUFFER_WIDTH) && (cursor_y < FRAMEBUFFER_HEIGHT);
    wire [14:0] cursor_pixel_address    = {cursor_y[7:0], 7'b0} + {cursor_y[7:0], 5'b0} + cursor_x[7:0];  // only used when cursor_in_bounds
    wire [14:0] video_pixel_address    = {video_y,    7'b0} + {video_y,    5'b0} + video_x;

    wire        plot_pixel_now = (gpu_state == STATE_WAIT_FOR_COMMAND) && command_start && (command == COMMAND_PLOT) && cursor_in_bounds;
    wire        framebuffer_write_enable   = (gpu_state == STATE_CLEARING_FRAMEBUFFER) || plot_pixel_now;
    wire [14:0] framebuffer_write_address = (gpu_state == STATE_CLEARING_FRAMEBUFFER) ? clear_address : cursor_pixel_address;
    wire [7:0]  framebuffer_write_data = (gpu_state == STATE_CLEARING_FRAMEBUFFER) ? clear_color : argument[7:0];   // 8-bit color for now

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            gpu_state         <= STATE_CLEARING_FRAMEBUFFER; 
            cursor_x      <= 16'd0;
            cursor_y      <= 16'd0;
            clear_address    <= 15'd0;
            clear_color   <= 8'd0;
            command_done          <= 1'b0;
            present_frame_pulse <= 1'b0;
        end else begin
            command_done          <= 1'b0;
            present_frame_pulse <= 1'b0;

            case (gpu_state)
                STATE_CLEARING_FRAMEBUFFER: begin
                    if (clear_address == FRAMEBUFFER_PIXEL_COUNT - 1) begin
                        clear_address <= 15'd0;
                        gpu_state      <= STATE_WAIT_FOR_COMMAND;
                        command_done       <= 1'b1;
                    end else begin
                        clear_address <= clear_address + 15'd1;
                    end
                end
                STATE_WAIT_FOR_COMMAND: begin
                    if (command_start) begin
                        case (command)
                            COMMAND_SET_X: begin
                                cursor_x <= argument;
                                command_done     <= 1'b1;
                            end
                            COMMAND_SET_Y: begin
                                cursor_y <= argument;
                                command_done     <= 1'b1;
                            end
                            COMMAND_PLOT: begin
                                command_done <= 1'b1; 
                            end
                            COMMAND_CLEAR: begin
                                clear_color <= argument[7:0];
                                clear_address <= 15'd0;
                                gpu_state      <= STATE_CLEARING_FRAMEBUFFER; 
                            end
                            COMMAND_PRESENT: begin
                                present_frame_pulse <= 1'b1;
                                command_done          <= 1'b1;
                            end
                            default: command_done <= 1'b1;
                        endcase
                    end
                end
            endcase
        end
    end

    Gowin_SDPB u_framebuffer (
        .clka   (clk),
        .cea    (framebuffer_write_enable),
        .reseta (reset),
        .ada    (framebuffer_write_address),
        .din    (framebuffer_write_data),

        .clkb   (clk),
        .ceb    (1'b1),
        .resetb (reset),
        .oce    (1'b1),
        .adb    (video_pixel_address),
        .dout   (video_pixel)
    );

endmodule