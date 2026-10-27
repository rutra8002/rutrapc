module rutracpu_memory #(
    parameter MEMORY_ADDRESS_BITS = 10      // 2^10 = 1024 words (fits one 18Kb BSRAM)
)(
    input  wire                            clk,

    // bootloader write port
    input  wire                            boot_write_enable,
    input  wire [MEMORY_ADDRESS_BITS-1:0]  boot_write_address,
    input  wire [15:0]                     boot_write_data,

    // CPU read/write port
    input  wire                            cpu_write_enable,
    input  wire [MEMORY_ADDRESS_BITS-1:0]  cpu_address,
    input  wire [15:0]                     cpu_write_data,
    output reg  [15:0]                     cpu_read_data    // valid one cycle after cpu_address
);
    reg [15:0] memory_words [0:(1<<MEMORY_ADDRESS_BITS)-1];

    wire                           write_enable  = boot_write_enable | cpu_write_enable;
    wire [MEMORY_ADDRESS_BITS-1:0] access_address = boot_write_enable ? boot_write_address : cpu_address;
    wire [15:0]                    write_data    = boot_write_enable ? boot_write_data    : cpu_write_data;

    always @(posedge clk) begin
        if (write_enable) memory_words[access_address] <= write_data;
        cpu_read_data <= memory_words[access_address];
    end

    integer word_index;
    initial for (word_index = 0; word_index < (1<<MEMORY_ADDRESS_BITS); word_index = word_index + 1)
        memory_words[word_index] = 16'h0000;                  // PASS
endmodule