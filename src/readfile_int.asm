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
        ; PUSH ES
        PUSH BX
        PUSH CX
        PUSH DX
        PUSH DI

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

	MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
        MOV WORD[INT_DIRECTORY_FIRST_SECTOR], AX

        MOV SI, TEMP_BUFFER
        MOV DI, INT_FILENAME_BUFFER
        XOR BX, BX
        MOV ES, BX
        MOV BX, WORD[WORKING_DIRECTORY]
        MOV DL, BYTE[DRIVE_NUMBER]
        CALL CONVERT_LE_AND_TRAVERSE
	MOV BYTE[INT_RET_CODE], DH
        JC .LABEL_HACK

	MOV SI, INT_FILENAME_BUFFER
        CALL FIND_ENTRY ; <- schlampisch
	MOV BYTE[INT_RET_CODE], 0x43
        JC .LABEL_HACK

        MOV WORD[IO_BYTES], 0

	TEST BYTE[ES:BX + 11], 0x10
	MOV BYTE[INT_RET_CODE], 0x45 ; <- Stupid, rewrite this in a less hacky way
	JNZ .IS_DIRECTORY_ERROR

        MOV AX, WORD[ES:BX + 28]
        MOV WORD[FILE_SIZE_LOWER], AX
        MOV AX, WORD[ES:BX + 30]
        MOV WORD[FILE_SIZE_UPPER], AX

        MOV AX, WORD[ES:BX + 26]

.LABEL_HACK:
        POP DI
        POP DX
        POP CX
        POP BX
        JC .ERROR
        POP ES
        PUSH ES

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
        ; SHR BX, 4
	SHR BX, 1
	SHR BX, 1
	SHR BX, 1
	SHR BX, 1
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
	MOV BYTE[INT_RET_CODE], DH
        POP DX
        POP BX
        POP ES
        JC .ERROR

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
        ; SHR DI, 4
	SHR DI, 1
	SHR DI, 1
	SHR DI, 1
	SHR DI, 1

        PUSH DX
        ; SHR DX, 4
	SHR DX, 1
	SHR DX, 1
	SHR DX, 1
	SHR DX, 1

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
        CALL RESTORE_WORKING_DIRECTORY
        JC .READ_ERROR

        ; POP ES
        ; POP DS
        JMP RW_RET_INT

.ERROR:
	CALL RESTORE_WORKING_DIRECTORY
	JC .READ_ERROR
	
	JMP RW_RET_INT

.READ_ERROR:
        CALL RESTORE_WORKING_DIRECTORY

        JMP RW_RET_INT

.NOT_FOUND_ERROR:
        CALL RESTORE_WORKING_DIRECTORY
        JC .READ_ERROR

        JMP RW_RET_INT

.IS_DIRECTORY_ERROR:
	POP DI
	POP DX
	POP CX
	POP BX

	CALL RESTORE_WORKING_DIRECTORY
	JC .READ_ERROR

	JMP RW_RET_INT
