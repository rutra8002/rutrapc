module rutracpu_rom (
    input wire [7:0] address,
    output wire [11:0] instruction
);
    reg [11:0] rom [0:255];
    assign instruction = rom[address];

    integer i;
    initial begin
        // Default-fill so simulation doesn't show garbage past the program end.
        for (i = 0; i < 256; i = i + 1)
            rom[i] = 12'h000; // PASS

        // ------------------------------------------------------------
        // Demo program: draws a diagonal line on the GPU's 16x16
        // framebuffer from (0,0) to (15,15), then PRESENTs and HALTs.
        //
        // ------------------------------------------------------------
        rom[ 0] = 12'h100; // LOAD_IMMEDIATE 0            ; i = 0
        rom[ 1] = 12'h510; // STORE 0x10                  ; ram[0x10] = i
        // loop: (address 2)
        rom[ 2] = 12'h1F0; // LOAD_IMMEDIATE 0xF0         ; CMD_SET_X
        rom[ 3] = 12'h900; // OUTPUT_CHAR
        rom[ 4] = 12'h410; // LOAD 0x10                   ; acc = i
        rom[ 5] = 12'h900; // OUTPUT_CHAR                 ; send x = i
        rom[ 6] = 12'h1F1; // LOAD_IMMEDIATE 0xF1         ; CMD_SET_Y
        rom[ 7] = 12'h900; // OUTPUT_CHAR
        rom[ 8] = 12'h410; // LOAD 0x10                   ; acc = i
        rom[ 9] = 12'h900; // OUTPUT_CHAR                 ; send y = i
        rom[10] = 12'h1F2; // LOAD_IMMEDIATE 0xF2         ; CMD_PLOT
        rom[11] = 12'h900; // OUTPUT_CHAR
        rom[12] = 12'h101; // LOAD_IMMEDIATE 1            ; pixel on
        rom[13] = 12'h900; // OUTPUT_CHAR
        rom[14] = 12'h410; // LOAD 0x10                   ; acc = i
        rom[15] = 12'h201; // ADD_IMMEDIATE 1             ; acc = i+1
        rom[16] = 12'h510; // STORE 0x10                  ; ram[0x10] = i+1
        rom[17] = 12'h310; // SUBTRACT_IMMEDIATE 16       ; acc = (i+1)-16
        rom[18] = 12'h714; // JUMP_IF_ZERO 20             ; if i+1==16 -> done
        rom[19] = 12'h602; // JUMP 2                      ; else loop again
        // done: (address 20)
        rom[20] = 12'h1F4; // LOAD_IMMEDIATE 0xF4         ; CMD_PRESENT
        rom[21] = 12'h900; // OUTPUT_CHAR
        rom[22] = 12'hF00; // HALT
    end
endmodule