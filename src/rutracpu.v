module rutracpu (
    input wire clk,
    input wire reset,
    input wire [15:0] instruction,
    input wire consumed,
    output reg [7:0] pc,
    output reg [7:0] acc,
    output reg [7:0] out_data,
    output reg out_valid,
    output reg out_is_char,
    output reg halted,

    output reg [3:0] gpu_cmd,
    output reg [7:0] gpu_arg,
    output reg       gpu_start,
    input  wire      gpu_done
);
    reg [7:0] ram [0:255];
    reg out_pending;
    reg gpu_pending;

    wire [7:0] opcode      = instruction[15:8];
    wire [7:0] operand_imm = instruction[7:0];

    localparam [3:0] GPU_SETX    = 4'd0;
    localparam [3:0] GPU_SETY    = 4'd1;
    localparam [3:0] GPU_PLOT    = 4'd2;
    localparam [3:0] GPU_CLEAR   = 4'd3;
    localparam [3:0] GPU_PRESENT = 4'd4;

    initial begin
        pc = 8'd0;
        acc = 8'd0;
        out_data = 8'd0;
        out_valid = 1'b0;
        out_is_char = 1'b0;
        halted = 1'b0;
        out_pending = 1'b0;
        gpu_cmd = 4'd0;
        gpu_arg = 8'd0;
        gpu_start = 1'b0;
        gpu_pending = 1'b0;
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
            gpu_cmd <= 4'd0;
            gpu_arg <= 8'd0;
            gpu_start <= 1'b0;
            gpu_pending <= 1'b0;
        end else if (!halted) begin
            if (out_pending) begin
                if (consumed) begin
                    out_valid   <= 1'b0;
                    out_pending <= 1'b0;
                    pc          <= pc + 8'd1;
                end
            end else if (gpu_pending) begin
                gpu_start <= 1'b0;
                if (gpu_done) begin
                    gpu_pending <= 1'b0;
                    pc          <= pc + 8'd1;
                end
            end else begin
                out_valid <= 1'b0;
                case (opcode)
                    8'h00: pc <= pc + 8'd1;                                          // PASS
                    8'h01: begin                                                     // LOAD_IMMEDIATE imm8
                        acc <= operand_imm;
                        pc <= pc + 8'd1; 
                    end
                    8'h02: begin                                                     // ADD_IMMEDIATE imm8
                        acc <= acc + operand_imm;
                        pc <= pc + 8'd1;
                    end
                    8'h03: begin                                                     // SUBTRACT_IMMEDIATE imm8
                        acc <= acc - operand_imm; 
                        pc <= pc + 8'd1;
                    end
                    8'h04: begin                                                     // LOAD address
                        acc <= ram[operand_imm]; 
                        pc <= pc + 8'd1; 
                    end
                    8'h05: begin                                                     // STORE address      
                        ram[operand_imm] <= acc; 
                        pc <= pc + 8'd1; 
                    end
                    8'h06: pc <= operand_imm;                                        // JUMP address
                    8'h07: begin                                                     // JUMP_IF_ZERO address
                        if (acc == 8'd0) 
                            pc <= operand_imm;
                        else
                            pc <= pc + 8'd1;
                    end
                    8'h08: begin                                                     // OUTPUT_INT
                        out_data    <= acc;
                        out_is_char <= 1'b0;
                        out_valid   <= 1'b1;
                        out_pending <= 1'b1;
                    end
                    8'h09: begin                                                     // OUTPUT_CHAR
                        out_data    <= acc;
                        out_is_char <= 1'b1;
                        out_valid   <= 1'b1;
                        out_pending <= 1'b1;
                    end
                    8'h0A: begin                                                     // GPU_SETX (x = acc)
                        gpu_cmd <= GPU_SETX; gpu_arg <= acc; gpu_start <= 1'b1; gpu_pending <= 1'b1;
                    end
                    8'h0B: begin                                                     // GPU_SETY (y = acc)
                        gpu_cmd <= GPU_SETY; gpu_arg <= acc; gpu_start <= 1'b1; gpu_pending <= 1'b1;
                    end
                    8'h0C: begin                                                     // GPU_PLOT (pixel = acc)
                        gpu_cmd <= GPU_PLOT; gpu_arg <= acc; gpu_start <= 1'b1; gpu_pending <= 1'b1;
                    end
                    8'h0D: begin                                                     // GPU_CLEAR
                        gpu_cmd <= GPU_CLEAR; gpu_start <= 1'b1; gpu_pending <= 1'b1;
                    end
                    8'h0E: begin                                                     // GPU_PRESENT
                        gpu_cmd <= GPU_PRESENT; gpu_start <= 1'b1; gpu_pending <= 1'b1;
                    end
                    8'h0F: halted <= 1'b1;                                           // HALT
                    default: pc <= pc + 8'd1;
                endcase
            end
        end
    end
endmodule