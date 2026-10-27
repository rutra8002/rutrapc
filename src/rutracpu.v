module rutracpu #(
    parameter MEMORY_ADDRESS_BITS = 10                 // memory = 2^MEMORY_ADDRESS_BITS words
)(
    input  wire        clk,
    input  wire        reset,

    // unified 16-bit memory
    output wire [MEMORY_ADDRESS_BITS-1:0] cpu_memory_address,
    output wire        cpu_memory_write_enable,
    output wire [15:0] cpu_memory_write_data,
    input  wire [15:0] cpu_memory_read_data,           // valid one cycle after cpu_memory_address

    input  wire        consumed,
    output reg  [15:0] pc,
    output reg  [15:0] r1,
    output reg  [15:0] r2,
    output reg  [7:0]  out_data,            // UART is still 8-bit, 16-bit values go out as 2 bytes
    output reg         out_valid,
    output reg         out_is_char,
    output reg         halted,

    output reg  [3:0]  gpu_cmd,
    output reg  [15:0] gpu_arg,
    output reg         gpu_start,
    input  wire        gpu_ready,
    input  wire        gpu_done
);
    localparam [3:0] GPU_SETX    = 4'd0;
    localparam [3:0] GPU_SETY    = 4'd1;
    localparam [3:0] GPU_PLOT    = 4'd2;
    localparam [3:0] GPU_CLEAR   = 4'd3;
    localparam [3:0] GPU_PRESENT = 4'd4;

    localparam [3:0] STATE_FETCH_INSTRUCTION    = 4'd0;
    localparam [3:0] STATE_DECODE_INSTRUCTION   = 4'd1;
    localparam [3:0] STATE_REQUEST_NUMBER_WORD = 4'd2;
    localparam [3:0] STATE_RECEIVE_NUMBER_WORD      = 4'd3; 
    localparam [3:0] STATE_EXECUTE     = 4'd4;
    localparam [3:0] STATE_REQUEST_MEMORY_READ       = 4'd5;
    localparam [3:0] STATE_RECEIVE_MEMORY_READ   = 4'd6;
    localparam [3:0] STATE_MEMORY_WRITE       = 4'd7;
    localparam [3:0] STATE_WAIT_FOR_UART      = 4'd8; 
    localparam [3:0] STATE_WAIT_FOR_GPU      = 4'd9; 

    reg [3:0]  cpu_state;
    reg [15:0] instruction_word;
    reg [15:0] number_word;
    reg [15:0] next_pc; 
    reg [15:0] data_address;
    reg        output_low_byte_pending;

    wire [7:0]  opcode = instruction_word[15:8];
    wire        register_a_is_r2 = instruction_word[0];   // 0 = r1, 1 = r2
    wire        register_b_is_r2 = instruction_word[1];
    wire [15:0] register_a_value = register_a_is_r2 ? r2 : r1;
    wire [15:0] register_b_value = register_b_is_r2 ? r2 : r1;

    // opcodes that are followed by a 16-bit number word
    function is_two_word_instruction;
        input [7:0] op;
        begin
            case (op)
                8'h01, 8'h02, 8'h03, 8'h04, 8'h05, 8'h06, 8'h07, 8'h10: is_two_word_instruction = 1'b1;
                default: is_two_word_instruction = 1'b0;
            endcase
        end
    endfunction

    wire [15:0] memory_address_full = (cpu_state == STATE_REQUEST_NUMBER_WORD)             ? pc + 16'd1 :
                            (cpu_state == STATE_REQUEST_MEMORY_READ || cpu_state == STATE_MEMORY_WRITE)  ? data_address  : pc;
    assign cpu_memory_address  = memory_address_full[MEMORY_ADDRESS_BITS-1:0];
    assign cpu_memory_write_enable    = (cpu_state == STATE_MEMORY_WRITE);
    assign cpu_memory_write_data = register_a_value;

    initial begin
        cpu_state = STATE_FETCH_INSTRUCTION;
        pc = 16'd0; r1 = 16'd0; r2 = 16'd0;
        instruction_word = 16'd0; number_word = 16'd0; next_pc = 16'd0; data_address = 16'd0;
        out_data = 8'd0; out_valid = 1'b0; out_is_char = 1'b0; output_low_byte_pending = 1'b0;
        halted = 1'b0;
        gpu_cmd = 4'd0; gpu_arg = 16'd0; gpu_start = 1'b0;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cpu_state <= STATE_FETCH_INSTRUCTION;
            pc <= 16'd0; r1 <= 16'd0; r2 <= 16'd0;
            instruction_word <= 16'd0; number_word <= 16'd0; next_pc <= 16'd0; data_address <= 16'd0;
            out_data <= 8'd0; out_valid <= 1'b0; out_is_char <= 1'b0; output_low_byte_pending <= 1'b0;
            halted <= 1'b0;
            gpu_cmd <= 4'd0; gpu_arg <= 16'd0; gpu_start <= 1'b0;
        end else if (!halted) begin
            case (cpu_state)
                STATE_FETCH_INSTRUCTION: cpu_state <= STATE_DECODE_INSTRUCTION;

                STATE_DECODE_INSTRUCTION: begin
                    instruction_word <= cpu_memory_read_data;
                    if (is_two_word_instruction(cpu_memory_read_data[15:8])) begin
                        next_pc   <= pc + 16'd2;
                        cpu_state <= STATE_REQUEST_NUMBER_WORD;
                    end else begin
                        next_pc   <= pc + 16'd1;
                        cpu_state <= STATE_EXECUTE;
                    end
                end

                STATE_REQUEST_NUMBER_WORD: cpu_state <= STATE_RECEIVE_NUMBER_WORD;

                STATE_RECEIVE_NUMBER_WORD: begin
                    number_word   <= cpu_memory_read_data;
                    cpu_state <= STATE_EXECUTE;
                end

                STATE_EXECUTE: begin
                    cpu_state <= STATE_FETCH_INSTRUCTION;
                    pc    <= next_pc;                       // default: go to next instruction
                    case (opcode)
                        8'h00: ;                                                        // PASS
                        8'h01: if (register_a_is_r2) r2 <= number_word;            else r1 <= number_word;         // LOAD_IMMEDIATE ra, n
                        8'h02: if (register_a_is_r2) r2 <= register_a_value + number_word;   else r1 <= register_a_value + number_word; // ADD_IMMEDIATE ra, n
                        8'h03: if (register_a_is_r2) r2 <= register_a_value - number_word;   else r1 <= register_a_value - number_word; // SUBTRACT_IMMEDIATE ra, n
                        8'h04: begin data_address <= number_word; pc <= pc; cpu_state <= STATE_REQUEST_MEMORY_READ; end     // LOAD ra, address
                        8'h05: begin data_address <= number_word; pc <= pc; cpu_state <= STATE_MEMORY_WRITE; end     // STORE ra, address
                        8'h06: pc <= number_word;                                               // JUMP address
                        8'h07: if (register_a_value == 16'd0) pc <= number_word;                          // JUMP_IF_ZERO ra, address
                        8'h10: if (register_a_value != 16'd0) pc <= number_word;                          // JUMP_IF_NOT_ZERO ra, address

                        8'h08: begin                                                    // OUTPUT_INT ra (2 bytes: high, low)
                            out_data <= register_a_value[15:8]; out_is_char <= 1'b0;
                            out_valid <= 1'b1; output_low_byte_pending <= 1'b1;
                            pc <= pc; cpu_state <= STATE_WAIT_FOR_UART;
                        end
                        8'h09: begin                                                    // OUTPUT_CHAR ra (low byte)
                            out_data <= register_a_value[7:0]; out_is_char <= 1'b1;
                            out_valid <= 1'b1; output_low_byte_pending <= 1'b0;
                            pc <= pc; cpu_state <= STATE_WAIT_FOR_UART;
                        end

                        8'h0A: begin gpu_cmd <= GPU_SETX;  gpu_arg <= register_a_value; gpu_start <= 1'b1; pc <= pc; cpu_state <= STATE_WAIT_FOR_GPU; end
                        8'h0B: begin gpu_cmd <= GPU_SETY;  gpu_arg <= register_a_value; gpu_start <= 1'b1; pc <= pc; cpu_state <= STATE_WAIT_FOR_GPU; end
                        8'h0C: begin gpu_cmd <= GPU_PLOT;  gpu_arg <= register_a_value; gpu_start <= 1'b1; pc <= pc; cpu_state <= STATE_WAIT_FOR_GPU; end
                        8'h0D: begin gpu_cmd <= GPU_CLEAR; gpu_arg <= register_a_value; gpu_start <= 1'b1; pc <= pc; cpu_state <= STATE_WAIT_FOR_GPU; end
                        8'h0E: begin gpu_cmd <= GPU_PRESENT;                  gpu_start <= 1'b1; pc <= pc; cpu_state <= STATE_WAIT_FOR_GPU; end

                        8'h0F: begin halted <= 1'b1; pc <= pc; end                      // HALT

                        8'h11: if (register_a_is_r2) r2 <= register_b_value;                 else r1 <= register_b_value;                 // MOVE ra, rb      (ra = rb)
                        8'h12: if (register_a_is_r2) r2 <= register_a_value + register_b_value;        else r1 <= register_a_value + register_b_value;        // ADD ra, rb       (ra = ra + rb)
                        8'h13: if (register_a_is_r2) r2 <= register_a_value - register_b_value;        else r1 <= register_a_value - register_b_value;        // SUBTRACT ra, rb  (ra = ra - rb)
                        8'h14: begin data_address <= register_b_value; pc <= pc; cpu_state <= STATE_REQUEST_MEMORY_READ; end // LOAD_INDIRECT ra, rb   (ra = mem[rb])
                        8'h15: begin data_address <= register_b_value; pc <= pc; cpu_state <= STATE_MEMORY_WRITE; end // STORE_INDIRECT ra, rb  (mem[rb] = ra)
                        default: ;                                                      // unknown = PASS
                    endcase
                end

                STATE_REQUEST_MEMORY_READ: cpu_state <= STATE_RECEIVE_MEMORY_READ;

                STATE_RECEIVE_MEMORY_READ: begin
                    if (register_a_is_r2) r2 <= cpu_memory_read_data; else r1 <= cpu_memory_read_data;
                    pc    <= next_pc;
                    cpu_state <= STATE_FETCH_INSTRUCTION;
                end

                STATE_MEMORY_WRITE: begin                                 // cpu_memory_write_enable is high this cycle
                    pc    <= next_pc;
                    cpu_state <= STATE_FETCH_INSTRUCTION;
                end

                STATE_WAIT_FOR_UART: if (consumed) begin
                    if (output_low_byte_pending) begin
                        out_data   <= register_a_value[7:0];          // send the low byte next
                        output_low_byte_pending <= 1'b0;
                    end else begin
                        out_valid <= 1'b0;
                        pc        <= next_pc;
                        cpu_state     <= STATE_FETCH_INSTRUCTION;
                    end
                end

                STATE_WAIT_FOR_GPU: begin
                    if (gpu_start) begin
                        if (gpu_ready) gpu_start <= 1'b0;
                    end else if (gpu_done) begin
                        pc    <= next_pc;
                        cpu_state <= STATE_FETCH_INSTRUCTION;
                    end
                end

                default: cpu_state <= STATE_FETCH_INSTRUCTION;
            endcase
        end
    end
endmodule