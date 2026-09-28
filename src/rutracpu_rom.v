module rutracpu_rom (
    input wire [7:0] address,
    output wire [15:0] instruction
);
    reg [15:0] rom [0:255];
    assign instruction = rom[address];

    integer i;
    initial begin
        // Default-fill so simulation doesn't show garbage past the program end.
        for (i = 0; i < 256; i = i + 1)
            rom[i] = 16'h0000; // PASS

        // ------------------------------------------------------------
        // Demo program: draws a diagonal line on the GPU's 16x16
        // framebuffer from (0,0) to (15,15), then PRESENTs and HALTs.
        //
        // ------------------------------------------------------------
        rom[ 0] = 16'h0100; // LOAD_IMMEDIATE 0            ; i = 0
        rom[ 1] = 16'h0510; // STORE 0x10                  ; ram[0x10] = i
        // loop: (address 2)
        rom[ 2] = 16'h0410; // LOAD 0x10                   ; acc = i
        rom[ 3] = 16'h0A00; // GPU_SETX                    ; x = acc (= i)
        rom[ 4] = 16'h0B00; // GPU_SETY                    ; y = acc (still i, no reload needed)
        rom[ 5] = 16'h0101; // LOAD_IMMEDIATE 1            ; pixel on
        rom[ 6] = 16'h0C00; // GPU_PLOT                    ; plot(x, y) = acc
        rom[ 7] = 16'h0410; // LOAD 0x10                   ; acc = i
        rom[ 8] = 16'h0201; // ADD_IMMEDIATE 1             ; acc = i+1
        rom[ 9] = 16'h0510; // STORE 0x10                  ; ram[0x10] = i+1
        rom[10] = 16'h0310; // SUBTRACT_IMMEDIATE 16       ; acc = (i+1)-16
        rom[11] = 16'h070D; // JUMP_IF_ZERO 13             ; if i+1==16 -> done
        rom[12] = 16'h0602; // JUMP 2                      ; else loop again
        // done: (address 13)
        rom[13] = 16'h0E00; // GPU_PRESENT
        rom[14] = 16'h0148; // LOAD_IMMEDIATE 'H'
        rom[15] = 16'h0900; // OUTPUT_CHAR
        rom[16] = 16'h0169; // LOAD_IMMEDIATE 'i'
        rom[17] = 16'h0900; // OUTPUT_CHAR
        rom[18] = 16'h010D; // CR
        rom[19] = 16'h0900;
        rom[20] = 16'h010A; // LF
        rom[21] = 16'h0900;
        rom[22] = 16'h0F00; // HALT
    end
endmodule