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

        ; SHR AX, 12
	ROL AX, 1
	ROL AX, 1
	ROL AX, 1
	ROL AX, 1
	AND AX, 0x000F
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

        MOV DH, BYTE[ES:BX + 11]

        MOV BX, WORD[CONVERTED_8_3]
        CALL GET_DIRECTORY_SIZE

        CALL STORE_FAT
        JC INT_WRITE_ERROR

        CALL STORE_DIRECTORY
        JC INT_WRITE_ERROR

        TEST DH, 0x10
        JZ .OUT

        CMP DI, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
        JNE .OUT

        MOV AH, 0x12
        MOV SI, BACK_CMD
        INT 0x20 ; Problem je, da ne preverjam, ali je ta stvar uspela ali ne.

        CMP DI, WORD[DIRECTORY_RET_FIRST_SECTOR]
        JNE .OUT

        CALL UPDATE_WORKING_DIRECTORY_PATH ; Tole mal sus.

        MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
        MOV WORD[DIRECTORY_RET_FIRST_SECTOR], AX

        MOV AX, DOS_SEGMENT
        MOV ES, AX

        MOV SI, DIRECTORY_PATH
        MOV DI, PATH_INFO_BUFFER
        MOV CX, DIRECTORY_INFO_END - DIRECTORY_PATH
        CALL MEMCPY

.OUT:
	XOR AH, AH
	MOV DL, BYTE[DRIVE_NUMBER]
	INT 0x13
        JMP RET_CODE_INT

BACK_CMD: DB "..", 0x00
