; AH = 0x16
; SI = Source file.
; DI = Destination file.
COPY_FILE_INT:
        PUSH SI
        XOR AL, AL
        CALL FINDCHAR
        POP DX 

        MOV AX, DOS_SEGMENT
        MOV ES, AX 

        MOV WORD[ES:INT_TEMP], DI
        MOV DI, DS
        MOV WORD[ES:INT_TEMP_JUNIOR], DI

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

        MOV BYTE[INT_RET_CODE], DH
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
        JNZ INT_NOT_FOUND_ERROR ; <- Nared bl praviln error message.

        CMP BYTE[ES:BX], '.'
        JE INT_NOT_FOUND_ERROR

        PUSH DS
        PUSH ES
        MOV SI, ES
        MOV DS, SI
        MOV SI, BX
        MOV DI, DOS_SEGMENT
        MOV ES, DI
        MOV DI, SOURCE_ENTRY
        MOV CX, 32
        CALL MEMCPY
        POP ES
        POP DS

        XOR CX, CX
        MOV DI, AX
        MOV AX, WORD[SOURCE_ENTRY + 26]

.CHECK_FOR_AVAILABLE_SPACE:
        CALL GET_NEXT_CLUSTER

        PUSH AX
        CALL GET_FREE_CLUSTER
        POP AX
        JC INT_OUT_OF_SPACE_ERROR
	
        INC CX

        TEST AX, AX
        JZ .EMPTY_FILE

        CMP AX, 0xFF8
        JB .CHECK_FOR_AVAILABLE_SPACE

.EMPTY_FILE:
        MOV WORD[IO_BYTES], CX
        MOV AX, DI

        MOV SI, WORD[INT_TEMP]

        MOV DI, DS
        MOV ES, DI

        MOV DI, WORD[INT_TEMP_JUNIOR]
        MOV DS, DI

        PUSH CX
        CALL MAKE_ENTRY_PROC ; Bad naming.
        POP CX
	MOV BYTE[INT_RET_CODE], DH
        JC RET_CODE_INT

        MOV SI, FILENAME_BUFFER
        XOR DH, DH
        CALL CREATE_ENTRY
        JC INT_FILE_EXISTS_ERROR

        PUSH AX
        PUSH BX
        PUSH ES

        MOV AL, BYTE[SOURCE_ENTRY + 11]
        MOV BYTE[ES:DI + 11], AL

        MOV AX, WORD[SOURCE_ENTRY + 28]
        MOV WORD[ES:DI + 28], AX

        MOV AX, WORD[SOURCE_ENTRY + 30]
        MOV WORD[ES:DI + 30], AX

        MOV AX, WORD[SOURCE_ENTRY + 26]

        TEST AX, AX
        JZ .EMPTY_FILE1

        MOV SI, AX
        CALL GET_FREE_CLUSTER
        MOV WORD[ES:DI + 26], AX 

        MOV BX, DS
        MOV ES, BX
        MOV BX, DATA_BUFFER

        CALL GET_DIRECTORY_SIZE

        ; SHL CX, 5
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
        ADD BX, CX
        INC BX

        MOV CX, WORD[IO_BYTES]

.COPY_CLUSTERS_LOOP:
        PUSH AX
        MOV AX, SI
        CALL READ_DATA
        POP AX
        JC .READ_ERROR

        CALL WRITE_DATA
        JC .WRITE_ERROR

        DEC CX
        JZ .COPIED_CLUSTERS

        PUSH DX
        PUSH AX
        MOV AX, SI
        CALL GET_NEXT_CLUSTER
        MOV SI, AX

        CALL GET_FREE_CLUSTER
        MOV DX, AX
        POP AX
        CALL WRITE_CLUSTER
        POP DX

        CALL GET_NEXT_CLUSTER

        JMP .COPY_CLUSTERS_LOOP

.COPIED_CLUSTERS:
        PUSH DX
        MOV DX, 0x0FFF
        CALL WRITE_CLUSTER
        POP DX

.EMPTY_FILE1:
        POP ES
        POP BX
        POP AX

        CALL GET_DIRECTORY_SIZE
        CALL STORE_DIRECTORY
        JC INT_WRITE_ERROR

        CALL STORE_FAT
        JC INT_WRITE_ERROR

        JMP RET_CODE_INT

.READ_ERROR:
        POP ES
        POP BX
        POP AX

        MOV BYTE[INT_RET_CODE], 0x10
        JMP .RESTORE

.WRITE_ERROR:
        POP ES
        POP BX
        POP AX

        MOV BYTE[INT_RET_CODE], 0x0A ; <- Misleading error
        JMP .RESTORE

.RESTORE:
	XOR BX, BX
	MOV ES, BX
	MOV BX, FILESYSTEM ; Ne vidim razloga, da ne bi tale dodatek delou (morm pa Åe zares testirat).
        CALL LOAD_FAT

        CMP AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
        JNE RET_CODE_INT

        XOR BX, BX
        MOV ES, BX
        MOV BX, WORD[WORKING_DIRECTORY]
        CALL LOAD_DIRECTORY

        JMP RET_CODE_INT

SOURCE_ENTRY: TIMES 32 DB 0
