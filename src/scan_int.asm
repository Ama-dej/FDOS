; AH = 0x02
; SI = Pointer to buffer.
; CX = Maximum number of bytes to get from the user.
; Scan terminates when the enter key is pressed.
SCAN_INT:
        MOV DX, SI
        INC CX

.SCAN_LOOP:
        MOV AH, 0x00
        INT 0x16

        CMP AL, 0x0D
        JE RET_INT

        CMP AL, 0x08
        JE .BACKSPACE_PRESSED

        TEST CX, CX
        JZ .SCAN_LOOP

        MOV AH, 0x0E
        INT 0x10

        MOV BYTE[SI], AL
        INC SI
        LOOP .SCAN_LOOP

.BACKSPACE_PRESSED:
        CMP SI, DX
        JE .SCAN_LOOP

	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
        MOV AH, 0x03
        MOV BH, 0
        INT 0x10

        CMP DL, 0
        JNZ .MOVE_NORMAL

        MOV DL, 80
        DEC DH

.MOVE_NORMAL:
        MOV AH, 0x02
        DEC DL
        INT 0x10

        MOV AH, 0x0A
        MOV AL, ' '
        MOV BL, 7
        MOV CX, 1
        INT 0x10
	POP DX
	POP CX
	POP BX
	POP AX

        DEC SI
        MOV BYTE[SI], 0x00
        INC CX
        JMP .SCAN_LOOP
