; Diagonal line on the 16x16 framebuffer, then say "Hi" over UART.
        LOAD_IMMEDIATE 0
        STORE 0x10                  ; ram[0x10] = i
loop:   LOAD 0x10
        GPU_SETX
        GPU_SETY
        LOAD_IMMEDIATE 1
        GPU_PLOT
        LOAD 0x10
        ADD_IMMEDIATE 1
        STORE 0x10
        SUBTRACT_IMMEDIATE 16
        JUMP_IF_ZERO done
        JUMP loop
done:   GPU_PRESENT
        LOAD_IMMEDIATE 'H'
        OUTPUT_CHAR
        LOAD_IMMEDIATE 'i'
        OUTPUT_CHAR
        LOAD_IMMEDIATE 13
        OUTPUT_CHAR
        LOAD_IMMEDIATE 10
        OUTPUT_CHAR
        HALT