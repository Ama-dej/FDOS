; AH = 0x01
; SI = Pointer to string.
; CX = Number of bytes to print.
PRINT_INT:
        CLD

.PRINT_LOOP:
        TEST CX, CX
        JZ .OUT

        LODSB
        MOV AH, 0x0E
	MOV BX, 7
        INT 0x10

        DEC CX
        JMP .PRINT_LOOP

.OUT:
        JMP RET_INT
