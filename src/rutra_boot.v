module rutra_boot #(
    parameter [7:0] MAGIC_BYTE = 8'hB7,
    parameter ADDRESS_BITS = 10
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  uart_rx_data,
    input  wire        uart_rx_valid,

    output wire                     memory_write_enable,
    output wire [ADDRESS_BITS-1:0]  memory_write_address,
    output wire [15:0]              memory_write_data,
    output wire                     hold_cpu_in_reset
);
    localparam [2:0] STATE_WAIT_FOR_MAGIC_BYTE     = 3'd0;  // nothing loaded yet
    localparam [2:0] STATE_RECEIVE_LENGTH_HIGH     = 3'd1;
    localparam [2:0] STATE_RECEIVE_LENGTH_LOW      = 3'd5;
    localparam [2:0] STATE_RECEIVE_WORD_HIGH       = 3'd2;
    localparam [2:0] STATE_RECEIVE_WORD_LOW        = 3'd3;  // word is complete, write it
    localparam [2:0] STATE_RUN_PROGRAM             = 3'd4;  // CPU runs; a new MAGIC_BYTE starts a reload

    reg [2:0]               boot_state;
    reg [15:0]              words_remaining;
    reg [ADDRESS_BITS-1:0]  write_address;
    reg [7:0]               word_high_byte;
    reg                     program_loaded = 1'b0;

    assign memory_write_enable  = (boot_state == STATE_RECEIVE_WORD_LOW) & uart_rx_valid;
    assign memory_write_address = write_address;
    assign memory_write_data    = {word_high_byte, uart_rx_data};
    assign hold_cpu_in_reset    = (boot_state != STATE_RUN_PROGRAM);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            boot_state      <= program_loaded ? STATE_RUN_PROGRAM : STATE_WAIT_FOR_MAGIC_BYTE;
            words_remaining <= 16'd0;
            write_address   <= {ADDRESS_BITS{1'b0}};
            word_high_byte  <= 8'd0;
        end else if (uart_rx_valid) begin
            case (boot_state)
                STATE_WAIT_FOR_MAGIC_BYTE, STATE_RUN_PROGRAM:
                    if (uart_rx_data == MAGIC_BYTE) boot_state <= STATE_RECEIVE_LENGTH_HIGH;

                STATE_RECEIVE_LENGTH_HIGH: begin
                    words_remaining[15:8] <= uart_rx_data;
                    boot_state            <= STATE_RECEIVE_LENGTH_LOW;
                end

                STATE_RECEIVE_LENGTH_LOW: begin
                    words_remaining[7:0] <= uart_rx_data;
                    write_address        <= {ADDRESS_BITS{1'b0}};
                    if ({words_remaining[15:8], uart_rx_data} == 16'd0)
                        boot_state <= program_loaded ? STATE_RUN_PROGRAM : STATE_WAIT_FOR_MAGIC_BYTE;  // empty upload, ignore
                    else
                        boot_state <= STATE_RECEIVE_WORD_HIGH;
                end

                STATE_RECEIVE_WORD_HIGH: begin
                    word_high_byte <= uart_rx_data;
                    boot_state     <= STATE_RECEIVE_WORD_LOW;
                end

                STATE_RECEIVE_WORD_LOW: begin
                    write_address   <= write_address + 1'b1;
                    words_remaining <= words_remaining - 16'd1;
                    if (words_remaining == 16'd1) begin
                        program_loaded <= 1'b1;
                        boot_state     <= STATE_RUN_PROGRAM;
                    end else begin
                        boot_state <= STATE_RECEIVE_WORD_HIGH;
                    end
                end

                default: boot_state <= STATE_WAIT_FOR_MAGIC_BYTE;
            endcase
        end
    end
endmodule