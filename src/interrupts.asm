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
	MOV ES, AX

	MOV SI, PATH_INFO_BUFFER
	MOV DI, DIRECTORY_PATH
	MOV CX, DIRECTORY_INFO_END - DIRECTORY_PATH
	CALL MEMCPY

	MOV AX, WORD[DIRECTORY_RET_FIRST_SECTOR]
	CMP AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
	JE .NO_NEED_TO_LOAD

	MOV WORD[WORKING_DIRECTORY_FIRST_SECTOR], AX

	MOV BX, WORD[DIRECTORY_RET_SIZE]
	MOV WORD[DIRECTORY_SIZE], BX

	MOV DL, BYTE[DRIVE_RET_NUMBER]
	MOV BYTE[DRIVE_NUMBER], DL

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]
	MOV DL, BYTE[DRIVE_NUMBER]

	CALL LOAD_DIRECTORY

.NO_NEED_TO_LOAD:
        XOR AX, AX
        MOV SS, AX
        MOV SP, 0x7E00

	MOV SI, DS
	MOV ES, SI

	MOV SI, CLUSTERS_BUFFER
	MOV DI, FIRST_CLUSTERS
	MOV CX, 17
	CALL MEMCPY

        JMP DOS_SEGMENT:DOS_START

; AH = 0x01
; SI = Pointer to string.
; CX = Number of bytes to print.
PRINT_INT:
        CLD
        MOV AH, 0x0E

.PRINT_LOOP:
	TEST CX, CX
	JZ .OUT

        LODSB
        INT 0x10

	DEC CX
	JMP .PRINT_LOOP

.OUT:
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
        JC INT_NOT_FOUND_ERROR

        ; PUSH ES

        CMP DI, WORD[FILE_SIZE_UPPER]
        JA INT_READ_ERROR
        JB .SUBTRACT

        CMP DX, WORD[FILE_SIZE_LOWER]
        JA INT_READ_ERROR 

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

	PUSH DX
	MOV DL, BYTE[DRIVE_NUMBER]
        CALL READ_DATA
	POP DX
        POP BX
        POP ES
        JC INT_READ_ERROR

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
        JC INT_NOT_FOUND_ERROR
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
	JA INT_WRITE_ERROR
        JB .CONTINUE

        CMP DX, WORD[FILE_SIZE_LOWER]
	JA INT_WRITE_ERROR

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

	PUSH DX
	MOV DL, BYTE[DRIVE_NUMBER]
        CALL READ_DATA
	POP DX
        JNC .COPY_DATA

        POP ES
        POP BX
        POP BX
        POP ES
        POP CX
        JMP INT_WRITE_ERROR

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

	PUSH DX
	MOV DL, BYTE[DRIVE_NUMBER]
        CALL WRITE_DATA
	POP DX
        JC INT_WRITE_ERROR

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
        JMP RET_WRITE_INT

.OUT_OF_SPACE_ERROR:
        POP DX
        JMP INT_OUT_OF_SPACE_ERROR

INT_WRITE_LAST: DW 0

; AH = 0x12
; SI = Path string
CHANGE_DIRECTORY_INT:
	MOV DX, DOS_SEGMENT
	MOV ES, DX

        XOR CX, CX
        MOV BX, WORD[ES:WORKING_DIRECTORY]
        MOV ES, CX
        CALL TRAVERSE_PATH
        JNC .OK

	SHR AX, 12
	MOV DX, DOS_SEGMENT
	MOV ES, DX

	MOV BYTE[ES:INT_RET_CODE], AL
	JMP RET_CODE_INT

.OK:
	MOV CX, DOS_SEGMENT
	MOV DS, CX

        MOV WORD[WORKING_DIRECTORY_FIRST_SECTOR], AX

        CALL GET_DIRECTORY_SIZE
        MOV WORD[DIRECTORY_SIZE], CX

	JMP RET_CODE_INT

; TODO:
; - Posodobi trentutno delujočo mapo, če se pripeti v njej.

; Removes the entry (file or directory) given in SI (relative and absolute paths are accepted).
; AH = 0x13
; SI = Path string.
REMOVE_ENTRY_INT:
	PUSH SI
        XOR AL, AL
        CALL FINDCHAR
	POP DX 

	MOV DI, DOS_SEGMENT
	MOV ES, DI
	MOV DI, TEMP_BUFFER

	MOV CX, SI
	SUB CX, DX
	INC CX
	MOV SI, DX
	CLD

.COPY_LOOP:
	LODSB
	CALL TO_UPPER
	STOSB

	LOOP .COPY_LOOP

	MOV SI, DOS_SEGMENT
	MOV DS, SI
        MOV DX, TEMP_BUFFER
	MOV SI, DI
	SUB SI, 2

.FIND_DIRECTORIES_LOOP:
        CMP BYTE[SI], '/'
        JE .FOUND_IT

        CMP BYTE[SI], 0
        JE .NO_DIRECTORY

        DEC SI
        JMP .FIND_DIRECTORIES_LOOP

.NO_DIRECTORY:
        INC SI
        MOV DI, FILENAME_BUFFER
        CALL CONVERT_TO_8_3
        JC INT_NOT_FOUND_ERROR

        MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]

.CURRENT_DIRECTORY:
        XOR BX, BX
        MOV ES, BX
        MOV BX, WORD[WORKING_DIRECTORY]
        MOV DL, BYTE[DRIVE_NUMBER]

        JMP .OK

.FOUND_IT:
        INC SI
        MOV DI, FILENAME_BUFFER
        CALL CONVERT_TO_8_3
        JC INT_NOT_FOUND_ERROR

        CMP BYTE[SI], '.'
        JE INT_SYNTAX_ERROR

        MOV BYTE[SI], 0

        MOV SI, DX
        MOV BX, DATA_BUFFER
        CALL TRAVERSE_PATH
        JNC .NO_ERROR

	SHR AX, 12
	MOV BYTE[INT_RET_CODE], AL
	JMP RET_CODE_INT

.NO_ERROR:
	CMP AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
	JE .CURRENT_DIRECTORY

.OK:
        MOV WORD[CONVERTED_8_3], BX
        MOV SI, FILENAME_BUFFER

        CMP BYTE[SI], '.'
        JE INT_NOT_FOUND_ERROR

        CALL FIND_ENTRY
        JC INT_NOT_FOUND_ERROR

        TEST WORD[ES:BX + 11], 0x10
        JZ .FILE ; Pomen da je mapa.

        CMP BYTE[ES:BX], '.'
        JE INT_NOT_FOUND_ERROR

        MOV DI, AX
        MOV AX, WORD[ES:BX + 26]

        TEST AX, AX
        JZ INT_NOT_FOUND_ERROR

        MOV CX, BX
        PUSH ES

        MOV BX, DS
        MOV ES, BX
        MOV BX, DATA_BUFFER

        CALL LOAD_DIRECTORY

        ADD BX, 64

.CHECK_IF_EMPTY_LOOP:
        MOV AL, BYTE[ES:BX]

        ADD BX, 32

        TEST AL, AL
        JZ .EMPTY

        CMP AL, 0xE5
        JE .CHECK_IF_EMPTY_LOOP

        POP ES
        JMP INT_DIR_NOT_EMPTY_ERROR

.EMPTY:
        MOV AX, DI
        MOV BX, DATA_BUFFER
        CALL LOAD_DIRECTORY

        POP ES
        MOV BX, CX

.FILE:
        PUSH AX
        PUSH DX
        MOV AX, WORD[ES:BX + 26]
        MOV DI, AX

        TEST AX, AX
        JZ .REMOVE_ENTRY ; If AX is zero it means its an empty file.

        XOR DX, DX

.FREE_CLUSTERS:
        PUSH AX
        CALL GET_NEXT_CLUSTER
        MOV CX, AX
        POP AX

        CALL WRITE_CLUSTER

        MOV AX, CX
        CMP AX, 0xFF8
        JLE .FREE_CLUSTERS

.REMOVE_ENTRY:
        POP DX
        POP AX
        MOV BYTE[ES:BX], 0xE5

        MOV BX, WORD[CONVERTED_8_3]
        CALL GET_DIRECTORY_SIZE

        CALL STORE_FAT
        JC INT_WRITE_ERROR

        CALL STORE_DIRECTORY
        JC INT_WRITE_ERROR

        CMP DI, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
        JNE .OUT

        MOV AH, 0x12
        MOV SI, BACK_CMD
        INT 0x80

        CALL UPDATE_WORKING_DIRECTORY_PATH

	MOV AX, DOS_SEGMENT
	MOV ES, AX

	MOV SI, PATH_INFO_BUFFER
	MOV DI, DIRECTORY_PATH
	MOV CX, DIRECTORY_INFO_END - DIRECTORY_PATH
	CALL MEMCPY

.OUT:
        JMP RET_CODE_INT

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

; AH = 0x21
; DL = Error code.
PRINT_ERROR_MESSAGES_INT:
	MOV SI, DOS_SEGMENT
	MOV DS, SI

	DEC DL

	CMP DL, (ERROR_MSG_ADDRESS_END - ERROR_MSG_ADDRESS_START) / 2	
	JAE RET_INT

	CLD

	PUSHA
	MOV AH, 0x03
	XOR DH, DH
	INT 0x80
	POPA

	MOV BL, DL
	XOR BH, BH
	SHL BX, 1
	ADD BX, ERROR_MSG_ADDRESS_START

	MOV AH, 0x0E
	MOV SI, WORD[BX]

.PRINT_LOOP:
	LODSB

	TEST AL, AL
	JZ .STRING_END

	INT 0x10

	JMP .PRINT_LOOP

.STRING_END:
	MOV AL, '.'
	INT 0x10

	CALL NLCR

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

	MOV DL, BYTE[DRIVE_NUMBER]
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

INT_READ_ERROR:
	MOV BYTE[INT_RET_CODE], 0x01
	JMP RET_CODE_INT

INT_WRITE_ERROR:
	MOV BYTE[INT_RET_CODE], 0x02
	JMP RET_CODE_INT

INT_NOT_FOUND_ERROR:
	MOV BYTE[INT_RET_CODE], 0x03
	JMP RET_CODE_INT

INT_DIR_NOT_FOUND_ERROR:
	MOV BYTE[INT_RET_CODE], 0x04
	JMP RET_CODE_INT

INT_SYNTAX_ERROR:
	MOV BYTE[INT_RET_CODE], 0x05
	JMP RET_CODE_INT

INT_FILE_EXISTS_ERROR:
	MOV BYTE[INT_RET_CODE], 0x06
	JMP RET_CODE_INT

INT_FILE_NOT_DIR_ERROR:
	MOV BYTE[INT_RET_CODE], 0x07
	JMP RET_CODE_INT

INT_DIR_NOT_EMPTY_ERROR:
	MOV BYTE[INT_RET_CODE], 0x08
	JMP RET_CODE_INT

INT_OUT_OF_SPACE_ERROR:
	MOV BYTE[INT_RET_CODE], 0x09
	JMP RET_CODE_INT

INT_MAX_DIR_DEPTH:
	MOV BYTE[INT_RET_CODE], 0x0A
	JMP RET_CODE_INT

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
CHANGE_DIRECTORY_INT_ADDRESS: DW CHANGE_DIRECTORY_INT
REMOVE_ENTRY_INT_ADDRESS: DW REMOVE_ENTRY_INT
TIMES 12 DW RET_INT
; Other.
; ------
COMMAND_PARAMETERS_INT_ADDRESS: DW COMMAND_PARAMETERS_INT
PRINT_ERROR_MESSAGES_INT_ADDRESS: DW PRINT_ERROR_MESSAGES_INT
RETURN_FROM_INT_ADDRESS: TIMES 256 - ((RETURN_FROM_INT_ADDRESS - INT_JUMP_TABLE) / 2) DW RET_INT
INT_JUMP_TABLE_END:
