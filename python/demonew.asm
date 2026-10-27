; 16-bit demo: diagonal line, a 16-bit number over UART, then "OK"
        LOAD_IMMEDIATE r1, 0
        STORE r1, i              ; i = 0
loop:   LOAD r1, i
        GPU_SETX r1
        GPU_SETY r1
        LOAD_IMMEDIATE r2, 255
        GPU_PLOT r2              ; white pixel at (i, i)
        ADD_IMMEDIATE r1, 1
        STORE r1, i
        SUBTRACT_IMMEDIATE r1, 100
        JUMP_IF_NOT_ZERO r1, loop
        GPU_PRESENT

        LOAD_IMMEDIATE r1, 0x1234
        OUTPUT_INT r1            ; sends 0x12 then 0x34
        LOAD_IMMEDIATE r2, 'O'
        OUTPUT_CHAR r2
        MOVE r1, r2              ; register to register
        ADD r1, r2
        SUBTRACT r1, r2          ; r1 is 'O' again
        LOAD_IMMEDIATE r2, msg   ; pointer to data in the same memory
        LOAD_INDIRECT r1, r2     ; r1 = mem[msg] = 'K'
        OUTPUT_CHAR r1
        HALT

i:      .word 0
msg:    .word 'K'