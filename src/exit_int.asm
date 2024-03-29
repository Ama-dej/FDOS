; AH = 0x00
; Returns from the program to 16-DOS.
EXIT_INT:
        ; POPA
	POP DI
	POP SI
	POP BP
	POP SP
	POP DX
	POP CX
	POP BX
	POP AX

        XOR AX, AX
        MOV SS, AX
        MOV SP, (DOS_SEGMENT << 4) + DOS_OFFSET

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
        MOV SI, DS
        MOV ES, SI

        MOV SI, CLUSTERS_BUFFER
        MOV DI, FIRST_CLUSTERS
        MOV CX, 17
        CALL MEMCPY

        JMP DOS_SEGMENT:DOS_START
