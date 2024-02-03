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

        MOV SI, TEMP_BUFFER
        MOV DI, INT_FILENAME_BUFFER
        XOR BX, BX
        MOV ES, BX
        MOV BX, WORD[WORKING_DIRECTORY]
        MOV DL, BYTE[DRIVE_NUMBER]
        CALL CONVERT_LE_AND_TRAVERSE
        JC .LABEL_HACK

        CALL GET_DIRECTORY_SIZE
        MOV WORD[INT_DIRECTORY_SIZE], CX

        MOV WORD[INT_DIRECTORY_FIRST_SECTOR], AX

        MOV SI, INT_FILENAME_BUFFER
        CALL FIND_ENTRY
        JC .LABEL_HACK

        ; MOV AX, DOS_SEGMENT
        ; MOV ES, AX
        ; MOV DI, INT_FILENAME_BUFFER
        ; CALL CONVERT_TO_8_3
        ; JC .LABEL_HACK ; Evil hack to save a few instructions.

        ; MOV DS, AX
        ; MOV SI, INT_FILENAME_BUFFER
        ; MOV DI, BX

        ; XOR BX, BX
        ; MOV ES, BX
        ; MOV BX, WORD[WORKING_DIRECTORY]
        ; CALL FIND_ENTRY
        ; JC .LABEL_HACK

        ; MOV SI, DOS_SEGMENT
        ; MOV DS, SI

        MOV WORD[IO_BYTES], 0

        MOV AX, WORD[ES:BX + 28]
        MOV WORD[FILE_SIZE_LOWER], AX
        MOV AX, WORD[ES:BX + 30]
        MOV WORD[FILE_SIZE_UPPER], AX

        MOV AX, WORD[ES:BX + 26]
        MOV WORD[INT_TEMP], BX

.LABEL_HACK:
        POP DI
        POP DX
        POP CX
        POP BX
        ; POP ES
        JC .NOT_FOUND_ERROR
        POP ES
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
        JMP .WRITE_ERROR

.COPY_DATA:
        POP DS
        POP SI
        MOV DI, DATA_BUFFER
        ADD DI, DX
        CALL MEMCPY

        MOV SI, DOS_SEGMENT
        MOV DS, SI

        PUSH DX
        MOV DL, BYTE[DRIVE_NUMBER]
        CALL WRITE_DATA
        POP DX
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
        JMP RET_WRITE_INT

.READ_ERROR:
        CALL RESTORE_WORKING_DIRECTORY

        MOV BYTE[INT_RET_CODE], 0x01
        JMP RW_RET_INT

.WRITE_ERROR:
        CALL RESTORE_WORKING_DIRECTORY

        MOV BYTE[INT_RET_CODE], 0x02
        JMP RW_RET_INT

.NOT_FOUND_ERROR:
        CALL RESTORE_WORKING_DIRECTORY

        MOV BYTE[INT_RET_CODE], 0x03
        JMP RW_RET_INT

.OUT_OF_SPACE_ERROR:
        POP DX

        CALL RESTORE_WORKING_DIRECTORY
        JC .READ_ERROR

        MOV BYTE[INT_RET_CODE], 0x09
        JMP RW_RET_INT

INT_WRITE_LAST: DW 0
