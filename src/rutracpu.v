module rutracpu (
    input wire clk,
    input wire reset,
    input wire [11:0] instruction,
    input wire consumed,
    output reg [7:0] pc,
    output reg [7:0] acc,
    output reg [7:0] out_data,
    output reg out_valid,
    output reg out_is_char,
    output reg halted
);
    reg [7:0] ram [0:255];
    reg out_pending;
    reg out_second_pending;
    reg [7:0] out_second_data;

    wire [3:0] opcode = instruction[11:8];
    wire [7:0] operand_imm = instruction[7:0];

    localparam [7:0] GPU_CMD_SET_X   = 8'hF0;
    localparam [7:0] GPU_CMD_SET_Y   = 8'hF1;
    localparam [7:0] GPU_CMD_PLOT    = 8'hF2;
    localparam [7:0] GPU_CMD_CLEAR   = 8'hF3;
    localparam [7:0] GPU_CMD_PRESENT = 8'hF4;

    initial begin
        pc = 8'd0;
        acc = 8'd0;
        out_data = 8'd0;
        out_valid = 1'b0;
        out_is_char = 1'b0;
        halted = 1'b0;
        out_pending = 1'b0;
        out_second_pending = 1'b0;
        out_second_data = 8'd0;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 8'd0;
            acc <= 8'd0;
            out_data <= 8'd0;
            out_valid <= 1'b0;
            out_is_char <= 1'b0;
            halted <= 1'b0;
            out_pending <= 1'b0;
            out_second_pending <= 1'b0;
            out_second_data <= 8'd0;
        end else if (!halted) begin
            if (out_pending) begin
                if (consumed) begin
                    out_valid <= 1'b0;
                    // send second byte after first one is sent
                    if (out_second_pending) begin
                        out_data           <= out_second_data;
                        out_is_char        <= 1'b1;
                        out_valid          <= 1'b1;
                        out_second_pending <= 1'b0;
                    end else begin
                        out_pending <= 1'b0;
                        pc          <= pc + 8'd1;
                    end
                end
            end else begin
                out_valid <= 1'b0;
                case (opcode)
                    4'h0: pc <= pc + 8'd1;                     // PASS
                    4'h1: begin                                // LOAD_IMMEDIATE imm8
                        acc <= operand_imm;
                        pc <= pc + 8'd1;
                    end
                    4'h2: begin                                // ADD_IMMEDIATE imm8
                        acc <= acc + operand_imm;
                        pc <= pc + 8'd1;
                    end
                    4'h3: begin                                // SUBTRACT_IMMEDIATE imm8
                        acc <= acc - operand_imm;
                        pc <= pc + 8'd1;
                    end
                    4'h4: begin                                // LOAD address
                        acc <= ram[operand_imm];
                        pc <= pc + 8'd1;
                    end
                    4'h5: begin                                // STORE address
                        ram[operand_imm] <= acc;
                        pc <= pc + 8'd1;
                    end
                    4'h6: pc <= operand_imm;                   // JUMP address
                    4'h7: begin                                // JUMP_IF_ZERO address
                        if (acc == 8'd0)
                            pc <= operand_imm;
                        else
                            pc <= pc + 8'd1;
                    end
                    4'h8: begin                                // OUTPUT_INT
                        out_data    <= acc;
                        out_is_char <= 1'b0;
                        out_valid   <= 1'b1;
                        out_pending <= 1'b1;
                    end
                    4'h9: begin                                // OUTPUT_CHAR
                        out_data    <= acc;
                        out_is_char <= 1'b1;
                        out_valid   <= 1'b1;
                        out_pending <= 1'b1;
                    end
                    4'hA: begin                                // GPU_SETX   (x = acc)
                        out_data           <= GPU_CMD_SET_X;
                        out_is_char        <= 1'b1;
                        out_valid          <= 1'b1;
                        out_pending        <= 1'b1;
                        out_second_pending <= 1'b1;
                        out_second_data    <= acc;
                    end
                    4'hB: begin                                // GPU_SETY   (y = acc)
                        out_data           <= GPU_CMD_SET_Y;
                        out_is_char        <= 1'b1;
                        out_valid          <= 1'b1;
                        out_pending        <= 1'b1;
                        out_second_pending <= 1'b1;
                        out_second_data    <= acc;
                    end
                    4'hC: begin                                // GPU_PLOT   (pixel = acc)
                        out_data           <= GPU_CMD_PLOT;
                        out_is_char        <= 1'b1;
                        out_valid          <= 1'b1;
                        out_pending        <= 1'b1;
                        out_second_pending <= 1'b1;
                        out_second_data    <= acc;
                    end
                    4'hD: begin                                // GPU_CLEAR
                        out_data           <= GPU_CMD_CLEAR;
                        out_is_char        <= 1'b1;
                        out_valid          <= 1'b1;
                        out_pending        <= 1'b1;
                        out_second_pending <= 1'b0;
                    end
                    4'hE: begin                                // GPU_PRESENT
                        out_data           <= GPU_CMD_PRESENT;
                        out_is_char        <= 1'b1;
                        out_valid          <= 1'b1;
                        out_pending        <= 1'b1;
                        out_second_pending <= 1'b0;
                    end
                    4'hF: halted <= 1'b1;                      // HALT
                    default: pc <= pc + 8'd1;
                endcase
            end
        end
    end
endmodule