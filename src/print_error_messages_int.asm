; AH = 0x21
; DH = Error code.
PRINT_ERROR_MESSAGES_INT:
        MOV SI, DOS_SEGMENT
        MOV DS, SI

	MOV SI, STATUS_CODE_TABLE
	CLD

.FIND_STATUS_CODE:
	CMP SI, STATUS_CODE_TABLE_END
	JE .EXIT

	LODSB
	
	CMP AL, DH
	JE .FOUND_STATUS_CODE

	JMP .FIND_STATUS_CODE

.FOUND_STATUS_CODE:
	SUB SI, STATUS_CODE_TABLE + 1
	SHL SI, 1
	ADD SI, MSG_ADDRESS_TABLE

	MOV DI, SI
	MOV SI, WORD[DI]

	CMP BYTE[SI], 0x00
	JZ .EXIT

.PRINT_MESSAGE:
	LODSB

	TEST AL, AL
	JZ .MESSAGE_END

	CALL PUTCHAR

	JMP .PRINT_MESSAGE

.MESSAGE_END:
        CALL NLCR

.EXIT:
        JMP RET_INT
