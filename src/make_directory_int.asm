; AH = 0x15
; SI = Path to directory.
MAKE_DIRECTORY_INT:
        CALL MAKE_ENTRY_PROC
        JC RET_CODE_INT

        PUSH AX
        CALL GET_FREE_CLUSTER
        MOV CX, AX
        POP AX
        JC INT_OUT_OF_SPACE_ERROR

        MOV SI, FILENAME_BUFFER
        CALL CREATE_ENTRY
        JNC .NO_ERROR

        MOV BYTE[INT_RET_CODE], AL
        JMP RET_CODE_INT

.NO_ERROR:
        MOV WORD[ES:DI + 26], CX
        MOV WORD[ES:DI + 28], 0
        MOV WORD[ES:DI + 30], 0
        MOV BYTE[ES:DI + 11], 0x10

        PUSH CX
        CALL GET_DIRECTORY_SIZE
        CALL STORE_DIRECTORY
        POP CX
        JC ENTRY_WRITE_ERROR

        MOV WORD[INT_TEMP], DI
        MOV DI, ES
        MOV WORD[INT_TEMP_JUNIOR], DI
        MOV WORD[FILE_SIZE_LOWER], BX ; <- Horrible lable naming.
        MOV WORD[FILE_SIZE_UPPER], CX ; <- Ewww.

        MOV BX, DOS_SEGMENT
        MOV ES, BX
        MOV BX, DATA_BUFFER
        MOV SI, BACK_ENTRY
        MOV DI, BX
        MOV CX, 11
        CALL MEMCPY

        MOV WORD[ES:DI + 11], 0x10
        MOV SI, WORD[FILE_SIZE_UPPER]
        MOV WORD[ES:DI + 26], SI
        MOV WORD[ES:DI + 28], 0
        MOV WORD[ES:DI + 30], 0

        ADD DI, 32

        MOV SI, BACK_ENTRY
        CALL MEMCPY

        MOV BYTE[ES:DI + 1], '.'

        MOV WORD[ES:DI + 11], 0x10
        MOV WORD[ES:DI + 26], AX
        MOV WORD[ES:DI + 28], 0
        MOV WORD[ES:DI + 30], 0
        MOV BYTE[ES:DI + 32], 0

        MOV CX, 1
        PUSH AX
        MOV AX, WORD[FILE_SIZE_UPPER]
        CALL STORE_DIRECTORY
        POP AX
        JC ENTRY_WRITE_ERROR

        MOV DI, WORD[INT_TEMP_JUNIOR]
        MOV ES, DI
        MOV DI, WORD[INT_TEMP]
        MOV BX, WORD[FILE_SIZE_LOWER]

        MOV DI, WORD[FILE_SIZE_UPPER]

        PUSH DX
        MOV AX, DI
        MOV DX, 0x0FFF
        CALL WRITE_CLUSTER
        POP DX

        CALL STORE_FAT
        JC ENTRY_WRITE_ERROR

        JMP RET_CODE_INT

ENTRY_WRITE_ERROR:
        CMP AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
        JNE INT_WRITE_ERROR

        MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
        XOR BX, BX
        MOV ES, BX
        MOV BX, WORD[WORKING_DIRECTORY]
        CALL LOAD_DIRECTORY

        JMP INT_WRITE_ERROR

BACK_ENTRY: DB "."
TIMES 10 DB ' '
