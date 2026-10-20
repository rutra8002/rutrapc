; INITIALIZATION
LOAD_IMMEDIATE 0      ; Acc = 0
STORE 0x10            ; RAM[0x10] = X = 0
STORE 0x11            ; RAM[0x11] = Y = 0

LOAD_IMMEDIATE 1      ; Acc = 1
STORE 0x12            ; RAM[0x12] = Color = 1

LOAD_IMMEDIATE 120    ; Acc = 120 (Screen height for 160x120)
STORE 0x13            ; RAM[0x13] = Count = 120

; DRAW LOOP
LOOP_START:
; 1. Set X Coordinate
LOAD 0x10             ; Acc = X
GPU_SETX              ; Send X to GPU

; 2. Set Y Coordinate
LOAD 0x11             ; Acc = Y
GPU_SETY              ; Send Y to GPU

; 3. Plot the Pixel
LOAD 0x12             ; Acc = Color
GPU_PLOT              ; Command GPU to plot pixel with current Color

; 4. Increment X
LOAD 0x10             
ADD_IMMEDIATE 1       
STORE 0x10            

; 5. Increment Y
LOAD 0x11             
ADD_IMMEDIATE 1       
STORE 0x11            

; 6. Cycle the Color
LOAD 0x12             
ADD_IMMEDIATE 5       ; Add 5 to color value to create a distinct rainbow gradient
STORE 0x12            

; 7. Decrement Loop Counter
LOAD 0x13             
SUBTRACT_IMMEDIATE 1  
STORE 0x13            

; 8. Check for Loop Termination
JUMP_IF_ZERO END_LOOP ; If Acc (Count) == 0, jump to end

; 9. Continue Loop
JUMP LOOP_START       ; Unconditional jump back to start of loop

; CLEANUP & HALT
END_LOOP:
GPU_PRESENT           ; Push the framebuffer to the screen
HALT                  ; Stop CPU execution