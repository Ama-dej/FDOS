; FDOS INTERRUPT (INT 0x80)
; -------------------------

DOS_INT:
        PUSHA
	PUSH DS
	PUSH ES

        PUSH BX
        PUSH DS

        MOV BX, DOS_SEGMENT
        MOV DS, BX

        MOV BYTE[INT_RET_CODE], 0x00

        MOVZX BX, AH
        SHL BX, 1
        ADD BX, INT_JUMP_TABLE
        MOV AX, WORD[BX]

        POP DS
        POP BX

        JMP AX 

; AH = 0x00
; Returns from the program to 16-DOS.
EXIT_INT:
        POPA

        MOV AX, DOS_SEGMENT
        MOV DS, AX

	MOV AX, WORD[DIRECTORY_RET_SIZE]
	MOV WORD[DIRECTORY_SIZE], AX

	MOV AX, WORD[DIRECTORY_RET_FIRST_SECTOR]
	MOV WORD[WORKING_DIRECTORY_FIRST_SECTOR], AX

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]

	CALL LOAD_DIRECTORY
	
        XOR AX, AX
        MOV SS, AX
        MOV SP, 0x7E00

        JMP DOS_SEGMENT:DOS_START

; AH = 0x01
; SI = Pointer to string.
; CX = Number of bytes to print.
PRINT_INT:
        CLD
        MOV AH, 0x0E

.PRINT_LOOP:
        LODSB
        INT 0x10
        LOOP .PRINT_LOOP

        JMP RET_INT

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

        PUSHA
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
        POPA

        DEC SI
        MOV BYTE[SI], 0x00
        INC CX
        JMP .SCAN_LOOP

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

INT_FILENAME_BUFFER: TIMES 11 DB ' '

; AH = 0x10
; ES:BX = Destination buffer.
; SI = Pointer to filename.
; CX = Number of bytes to read.
; DX/DI = Byte offset
; DX = Lower part of offset.
; DI = Higher part of offset.
;
; CX -> Number of bytes read.
READFILE_INT:
        ; PUSH DS
        PUSH ES
        PUSH BX
        PUSH DI

        MOV AX, DOS_SEGMENT
        MOV ES, AX
        MOV DI, INT_FILENAME_BUFFER
        CALL CONVERT_TO_8_3
        JC .LABEL_HACK ; Evil hack to save a few instructions.

        MOV DS, AX
        MOV SI, INT_FILENAME_BUFFER
        MOV DI, BX

        XOR BX, BX
        MOV ES, BX
        MOV BX, WORD[WORKING_DIRECTORY]
        CALL FIND_ENTRY

        MOV SI, DOS_SEGMENT
        MOV DS, SI

	MOV WORD[IO_BYTES], 0

        MOV AX, WORD[ES:BX + 28]
        MOV WORD[FILE_SIZE_LOWER], AX
        MOV AX, WORD[ES:BX + 30]
        MOV WORD[FILE_SIZE_UPPER], AX

        MOV AX, WORD[ES:BX + 26]

.LABEL_HACK:
        POP DI
        POP BX
        POP ES
        JC .NOT_FOUND

        ; PUSH ES

        CMP DI, WORD[FILE_SIZE_UPPER]
        JA .READ_ERROR
        JB .SUBTRACT

        CMP DX, WORD[FILE_SIZE_LOWER]
        JA .READ_ERROR 

.SUBTRACT:
        SUB WORD[FILE_SIZE_UPPER], DI
        SUB WORD[FILE_SIZE_LOWER], DX
        SBB WORD[FILE_SIZE_UPPER], 0

        PUSH BX
        SHR BX, 4
        AND BX, 0xFFF0
        MOV SI, ES
        ADD SI, BX
        DEC SI
        MOV ES, SI
        POP BX
        AND BX, 0x00FF
        ADD BX, 16

        CALL RESET_DISK

.GET_TO_CLUSTER_OFFSET:
        CMP DI, 0
        JNZ .SKIP

        CMP DX, WORD[BYTES_PER_CLUSTER] 
        JB .READ_LOOP

.SKIP:
        SUB DX, WORD[BYTES_PER_CLUSTER]
        SBB DI, 0

        CALL GET_NEXT_CLUSTER
        JMP .GET_TO_CLUSTER_OFFSET

.READ_LOOP:
        PUSH ES
        PUSH BX

        MOV BX, DOS_SEGMENT
        MOV ES, BX
        MOV BX, DATA_BUFFER

        CALL READ_DATA
        POP BX
        POP ES
        JC .READ_ERROR

        CALL GET_NEXT_CLUSTER

        PUSH CX
        PUSH DI

        MOV DI, WORD[BYTES_PER_CLUSTER]

        CMP AX, 0xFF8
        JL .PROCEED

        CMP CX, WORD[FILE_SIZE_LOWER]
        JB .COPY_DATA

        MOV CX, WORD[FILE_SIZE_LOWER]
        JMP .COPY_DATA

.PROCEED:
        MOV CX, DI
        SUB CX, DX
        SUB WORD[FILE_SIZE_LOWER], CX
        SBB WORD[FILE_SIZE_UPPER], 0

.COPY_DATA:
        MOV SI, DATA_BUFFER
        ADD SI, DX
        MOV DI, BX
        CALL MEMCPY

	ADD WORD[IO_BYTES], CX

        POP DI
        POP CX

        MOV SI, CX
        ADD CX, DX
        ADD SI, DX
        JC .OVERFLOW

        CMP CX, WORD[BYTES_PER_CLUSTER]
        JBE .OUT

.OVERFLOW:
        SUB CX, WORD[BYTES_PER_CLUSTER]

        MOV DI, WORD[BYTES_PER_CLUSTER]
        SHR DI, 4

        PUSH DX
        SHR DX, 4

        MOV SI, ES
        ADD SI, DI
        SUB SI, DX
        MOV ES, SI
        POP DX

        AND DX, 0x000F
        SUB BX, DX

        CMP AX, 0xFF8
        JL .READ_LOOP

.OUT:
        ; POP ES
        ; POP DS
        JMP RW_RET_INT

.NOT_FOUND:
        MOV BYTE[INT_RET_CODE], 0x01
        ; POP DS
        JMP RW_RET_INT

.READ_ERROR:
        MOV BYTE[INT_RET_CODE], 0x02
        ; POP ES
        ; POP DS
        JMP RW_RET_INT

; AH = 0x11
; ES:BX = Buffer to write.
; SI = Pointer to file entry.
; CX = Number of bytes to write.
; DX/DI = Byte offset
; DX = Lower part of offset.
; DI = Higher part of offset.
;
; CX -> Number of bytes written.
WRITEFILE_INT:
        ; PUSH DS
        ; PUSH ES
        PUSH BX
        PUSH DI

        MOV AX, DOS_SEGMENT
        MOV ES, AX
        MOV DI, INT_FILENAME_BUFFER
        CALL CONVERT_TO_8_3
        JC .LABEL_HACK ; Evil hack to save a few instructions.

        MOV DS, AX
        MOV SI, INT_FILENAME_BUFFER
        MOV DI, BX

        XOR BX, BX
        MOV ES, BX
        MOV BX, WORD[WORKING_DIRECTORY]
        CALL FIND_ENTRY

        MOV SI, DOS_SEGMENT
        MOV DS, SI

	MOV WORD[IO_BYTES], 0

        MOV AX, WORD[ES:BX + 28]
        MOV WORD[FILE_SIZE_LOWER], AX
        MOV AX, WORD[ES:BX + 30]
        MOV WORD[FILE_SIZE_UPPER], AX

        MOV AX, WORD[ES:BX + 26]
        MOV WORD[INT_TEMP], BX

.LABEL_HACK:
        POP DI
        POP BX
        POP ES
        JC .NOT_FOUND
        PUSH ES

        PUSH BX
        SHR BX, 4
        AND BX, 0xFFF0
        MOV SI, ES
        ADD SI, BX
        DEC SI
        MOV ES, SI
        POP BX
        AND BX, 0x00FF
        ADD BX, 16

        CMP DI, WORD[FILE_SIZE_UPPER]
        JA .WRITE_ERROR
        JB .CONTINUE

        CMP DX, WORD[FILE_SIZE_LOWER]
        JA .WRITE_ERROR 

.CONTINUE:
        MOV WORD[FILE_SIZE_LOWER], DX
        MOV WORD[FILE_SIZE_UPPER], DI

        CALL RESET_DISK

        CMP AX, 0
        JNZ .GET_TO_STARTING_CLUSTER

        PUSH ES
        PUSH DX
        PUSH SI

        XOR SI, SI
        MOV ES, SI
        MOV SI, WORD[INT_TEMP]

        CALL GET_FREE_CLUSTER
        MOV WORD[ES:SI + 26], AX

        MOV DX, 0xFFF
        CALL WRITE_CLUSTER

        POP SI
        POP DX
        POP ES

.GET_TO_STARTING_CLUSTER:
        CMP DI, 0
        JNZ .SKIP

.SKIP:
        CMP DX, WORD[BYTES_PER_CLUSTER]
        JB .WRITE_LOOP

        SUB DX, WORD[BYTES_PER_CLUSTER]
        SBB DI, 0

        MOV WORD[INT_WRITE_LAST], AX
        CALL GET_NEXT_CLUSTER
        JMP .GET_TO_STARTING_CLUSTER

.WRITE_LOOP:
        CMP AX, 0xFF8
        JL .OK

        PUSH DX
        CALL GET_FREE_CLUSTER
        JC .OUT_OF_SPACE_ERROR

        MOV DX, 0xFFF
        CALL WRITE_CLUSTER

        MOV DX, AX
        MOV AX, WORD[INT_WRITE_LAST]
        CALL WRITE_CLUSTER

        MOV AX, DX

        POP DX

.OK:
        PUSH CX
        PUSH ES
        PUSH BX
        PUSH BX
        PUSH ES

        MOV BX, DOS_SEGMENT
        MOV ES, BX
        MOV BX, DATA_BUFFER

        MOV SI, CX
        ADD SI, DX
        JC .OVERFLOW ; This is here in case CX is a really high value and would therefore break this algorithm (eg. 0xFFFF + 0x200 = 0x1FF, which is smaller than the amount of bytes per cluster).

        PUSH CX
        ADD CX, DX
        CMP CX, WORD[BYTES_PER_CLUSTER]
        POP CX
        JB .READ_DATA

.OVERFLOW:
        MOV CX, WORD[BYTES_PER_CLUSTER]

        CMP DX, 0
        JZ .COPY_DATA

        SUB CX, DX

.READ_DATA:
        ; PUSH AX
        ; MOV AL, '*'
        ; CALL PUTCHAR
        ; POP AX

        CALL READ_DATA
        JNC .COPY_DATA

        POP ES
        POP BX
        POP BX
        POP ES
        POP CX
        JMP .WRITE_ERROR

.COPY_DATA:
        POP DS
        POP SI
        MOV DI, DATA_BUFFER
        ADD DI, DX
        CALL MEMCPY

        MOV SI, DOS_SEGMENT
        MOV DS, SI

        ; PUSHA
        ; MOV AH, 0x03
        ; MOV DX, CX
        ; INT 0x80
        ; CALL NLCR
        ; POPA

        CALL WRITE_DATA
        JC .WRITE_ERROR

        ; ADD WORD[FILE_SIZE_LOWER], CX
        ; ADC WORD[FILE_SIZE_UPPER], 0
	ADD WORD[IO_BYTES], CX

        POP BX
        POP ES
        POP CX

        MOV SI, CX
        ADD CX, DX
        ADD SI, DX
        JC .OVERFLOW_AGAIN

        CMP CX, WORD[BYTES_PER_CLUSTER]
        JBE .OUT

.OVERFLOW_AGAIN:
        SUB CX, WORD[BYTES_PER_CLUSTER]

        MOV DI, WORD[BYTES_PER_CLUSTER]
        SHR DI, 4

        PUSH DX
        SHR DX, 4

        MOV SI, ES
        ADD SI, DI
        SUB SI, DX
        MOV ES, SI 
        POP DX

        AND DX, 0x000F
        SUB BX, DX
        XOR DX, DX

        MOV WORD[INT_WRITE_LAST], AX
        CALL GET_NEXT_CLUSTER

        JMP .WRITE_LOOP

.OUT:
        ; POP ES
        JMP RET_WRITE_INT

.NOT_FOUND:
        MOV BYTE[INT_RET_CODE], 0x01
        JMP RET_WRITE_INT

.WRITE_ERROR:
        MOV BYTE[INT_RET_CODE], 0x02
        ; POP ES
        JMP RET_WRITE_INT

.OUT_OF_SPACE_ERROR:
        MOV BYTE[INT_RET_CODE], 0x03
        POP DX
        ; POP ES
        JMP RET_WRITE_INT

INT_WRITE_LAST: DW 0

; AH = 0x20
; DI = Pointer to 80 byte buffer.
COMMAND_PARAMETERS_INT:
        MOV SI, DS
        MOV ES, SI

        MOV SI, DOS_SEGMENT
        MOV DS, SI
        MOV SI, COMMAND_PARSED

        MOV CX, 80
        CALL MEMCPY

        MOV SI, ES
        MOV DS, SI

        JMP RET_INT

RET_WRITE_INT:
        ; PUSH ES

        XOR SI, SI
        MOV ES, SI
        MOV SI, WORD[INT_TEMP]

        MOV DX, WORD[FILE_SIZE_LOWER]
        MOV DI, WORD[FILE_SIZE_UPPER]
	MOV CX, WORD[IO_BYTES]
	ADD DX, CX
	ADC DI, 0

        CMP DI, WORD[ES:SI + 30]
        JB .POP
        JA .STORE

        CMP DX, WORD[ES:SI + 28]
        JB .POP

.STORE:
        MOV WORD[ES:SI + 30], DI
        MOV WORD[ES:SI + 28], DX

.POP:
        ; POP ES

        CALL UPDATE_FS
        ; POP DS
	JMP RW_RET_INT
        ; JMP RET_CODE_INT

RW_RET_INT:
	POP ES
	POP DS
	POPA
	PUSH DS
	MOV CX, DOS_SEGMENT
	MOV DS, CX
	MOV AL, BYTE[INT_RET_CODE]
	MOV CX, WORD[IO_BYTES]
	POP DS
	IRET

RET_CODE_INT:
	POP ES
	POP DS
        POPA
        PUSH BX
        PUSH DS 
        MOV BX, DOS_SEGMENT
        MOV DS, BX
        MOV AL, BYTE[INT_RET_CODE]
        POP DS
        POP BX
        IRET

RET_INT:
	POP ES
	POP DS
        POPA
        IRET

INT_RET_CODE: DB 0
INT_TEMP: DW 0
INT_TEMP_JUNIOR: DW 0

FILE_SIZE_LOWER: DW 0
FILE_SIZE_UPPER: DW 0
IO_BYTES: DW 0

INT_JUMP_TABLE:
; Exit interrupt and print routines.
; ----------------------------------
EXIT_INT_ADDRESS: DW EXIT_INT
PRINT_INT_ADDRESS: DW PRINT_INT
SCAN_INT_ADDRESS: DW SCAN_INT
PRINTI_INT_ADDRESS: DW PRINTI_INT
TIMES 12 DW RET_INT ; Space for more interrupts in the future.
; Filesystem routines.
; --------------------
READFILE_INT_ADDRESS: DW READFILE_INT
WRITEFILE_INT_ADDRESS: DW WRITEFILE_INT
TIMES 14 DW RET_INT
; Other.
; ------
COMMAND_PARAMETERS_INT_ADDRESS: DW COMMAND_PARAMETERS_INT
RETURN_FROM_INT_ADDRESS: TIMES 256 - ((RETURN_FROM_INT_ADDRESS - INT_JUMP_TABLE) / 2) DW RET_INT
INT_JUMP_TABLE_END:
