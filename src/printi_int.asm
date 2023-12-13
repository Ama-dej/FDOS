; AH = 0x03
; DX = Value to print.
PRINTI_INT:
        MOV AX, DX
        MOV BX, 10
        XOR CX, CX

.DIV_LOOP:
        XOR DX, DX
        DIV BX

        ADD DX, 48
        PUSH DX

        INC CX
        TEST AX, AX
        JNZ .DIV_LOOP

.PRINT_LOOP:
        POP AX
        MOV AH, 0x0E
        INT 0x10
        LOOP .PRINT_LOOP

        JMP RET_INT
