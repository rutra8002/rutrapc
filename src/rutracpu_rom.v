module rutracpu_rom (
    input  wire        clk,
    input  wire        we,
    input  wire [7:0]  waddr,
    input  wire [15:0] wdata,

    input  wire [7:0]  address,
    output wire [15:0] instruction
);
    reg [15:0] rom [0:255];
    assign instruction = rom[address];

    always @(posedge clk)
        if (we) rom[waddr] <= wdata;

    integer i;
    initial for (i = 0; i < 256; i = i + 1)
        rom[i] = 16'h0000;                  // PASS
endmodule