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
        rom[ 2] = 12'h410; // LOAD 0x10                   ; acc = i
        rom[ 3] = 12'hA00; // GPU_SETX                    ; x = acc (= i)
        rom[ 4] = 12'hB00; // GPU_SETY                    ; y = acc (still i, no reload needed)
        rom[ 5] = 12'h101; // LOAD_IMMEDIATE 1            ; pixel on
        rom[ 6] = 12'hC00; // GPU_PLOT                    ; plot(x, y) = acc
        rom[ 7] = 12'h410; // LOAD 0x10                   ; acc = i
        rom[ 8] = 12'h201; // ADD_IMMEDIATE 1             ; acc = i+1
        rom[ 9] = 12'h510; // STORE 0x10                  ; ram[0x10] = i+1
        rom[10] = 12'h310; // SUBTRACT_IMMEDIATE 16       ; acc = (i+1)-16
        rom[11] = 12'h70D; // JUMP_IF_ZERO 13             ; if i+1==16 -> done
        rom[12] = 12'h602; // JUMP 2                      ; else loop again
        // done: (address 13)
        rom[13] = 12'hE00; // GPU_PRESENT
        rom[14] = 12'hF00; // HALT
    end
endmodule