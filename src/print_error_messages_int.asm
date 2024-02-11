; AH = 0x21
; DL = Error code.
PRINT_ERROR_MESSAGES_INT:
        MOV SI, DOS_SEGMENT
        MOV DS, SI

        DEC DL

        CMP DL, (ERROR_MSG_ADDRESS_END - ERROR_MSG_ADDRESS_START) / 2
        JAE RET_INT

        CLD

        MOV BL, DL
        XOR BH, BH
        SHL BX, 1
        ADD BX, ERROR_MSG_ADDRESS_START

        MOV SI, WORD[BX]

.PRINT_LOOP:
        LODSB

        TEST AL, AL
        JZ .STRING_END

        MOV AH, 0x0E
	MOV BX, 7
        INT 0x10

        JMP .PRINT_LOOP

.STRING_END:
        MOV AH, 0x0E
	MOV BX, 7
        MOV AL, '.'
        INT 0x10

        CALL NLCR

        JMP RET_INT
