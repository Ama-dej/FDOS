; PROCEDURES
; ----------

; DL <- Drive number.
;
; AL -> Drive letter.
; CF -> Set if invalid drive number
DRIVE_TO_LETTER:
	CMP DL, 0x02
	JB .FLOPPY

	CMP DL, 0x80
	JB .INVALID

	CMP DL, 0x80 + 'Z' - 'C'
	JA .INVALID

	MOV AL, DL
	ADD AL, 'C' - 0x80
	RET

.FLOPPY:
	MOV AL, DL
	ADD AL, 'A'
	RET

.INVALID:
	STC
	RET

; AL <- Drive letter.
;
; DL -> Drive number.
; CF -> Set if invalid letter.
LETTER_TO_DRIVE:
	CALL TO_UPPER

	CMP AL, 'A'
	JB .INVALID

	CMP AL, 'Z'
	JA .INVALID

	MOV DL, AL

	CMP AL, 'C'
	JB .FLOPPY

	ADD DL, 0x80 - 'C'
	CLC
	RET

.FLOPPY:
	SUB DL, 'A'
	CLC
	RET

.INVALID:
	STC
	RET

; Sorts entries from lowest to highest.
;
; ES:SI <- Pointer to an array of entries.
; CX <- Array length.
SORT_ENTRIES:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI
	PUSH DS
	PUSH ES

	MOV DX, CX
	MOV CX, 11

.NEXT_CHARACTER:
	PUSH CX
	MOV WORD[.OFFSET], CX
	MOV CX, DX
	DEC CX

.NEXT_ENTRY:
	PUSH CX
	XOR CX, CX

.LOOP:
	MOV BX, CX
	; SHL BX, 5
	SHL BX, 1
	SHL BX, 1
	SHL BX, 1
	SHL BX, 1
	SHL BX, 1
	ADD BX, SI

	PUSH BX
	ADD BX, WORD[.OFFSET]
	DEC BX
	MOV AL, BYTE[ES:BX]
	MOV AH, BYTE[ES:BX + 32]
	POP BX

	CMP AL, AH
	JBE .CONT

	PUSH CX
	PUSH SI

	MOV CX, 32

	MOV AX, ES
	MOV DI, DS
	MOV ES, DI
	MOV DS, AX
	MOV SI, BX
	MOV DI, .TEMP_BUFFER
	CALL MEMCPY

	PUSH ES
	MOV ES, AX
	MOV DI, SI
	ADD SI, 32
	CALL MEMCPY

	POP DS
	MOV DI, SI
	MOV SI, .TEMP_BUFFER
	CALL MEMCPY

	POP SI
	POP CX

.CONT:
	POP AX 
	PUSH AX
	INC CX
	CMP CX, AX 
	JL .LOOP

	POP CX
	; DEC CX
	; JNZ .NEXT_ENTRY
	LOOP .NEXT_ENTRY

	POP CX
	; DEC CX
	; JNZ .NEXT_CHARACTER
	LOOP .NEXT_CHARACTER

.EXIT:
	POP ES
	POP DS
	POP DI
	POP SI
	POP DX
	POP CX
	POP BX
	POP AX
	RET

.OFFSET: DW 0
.TEMP_BUFFER: TIMES 32 DB 0

; Here to reuse code.
; Both interrupts for creating files and directories use literally the same code at the start.
MAKE_ENTRY_PROC:
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
        MOV DI, FILENAME_BUFFER
        MOV BX, DATA_BUFFER
        MOV DL, BYTE[DRIVE_NUMBER]
        CALL CONVERT_LE_AND_TRAVERSE
        JNC .OK

        MOV BYTE[INT_RET_CODE], DH
        STC
        JMP .NOT_WORKING_DIRECTORY

.OK:
        CMP AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
        JE .WORKING_DIRECTORY

        MOV BX, DATA_BUFFER
        MOV DL, BYTE[DRIVE_NUMBER]
        CLC
        JMP .NOT_WORKING_DIRECTORY

.WORKING_DIRECTORY:
        XOR BX, BX
        MOV ES, BX
        MOV BX, WORD[WORKING_DIRECTORY]
        MOV DL, BYTE[DRIVE_NUMBER]
        CLC

.NOT_WORKING_DIRECTORY:
        RET

;
RESTORE_WORKING_DIRECTORY:
	PUSH AX
	PUSH BX
	PUSH DX
	PUSH ES

	MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
	CMP WORD[INT_DIRECTORY_FIRST_SECTOR], AX
	JE .OUT

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]
	MOV DL, BYTE[DRIVE_NUMBER]
	CALL LOAD_DIRECTORY

.OUT:
	POP ES
	POP DX
	POP BX
	POP AX
	RET

; DH <- Entry attributes
; SI <- Converted 8_3 filename.
; ES:BX <- Directory location.
;
; If CF == 1 -> AL = Error code.
; ES:DI -> Entry location.
CREATE_ENTRY:
	PUSH CX
	PUSH SI

        MOV DI, BX
        ; MOV SI, FILENAME_BUFFER
        CALL FIND_ENTRY
        JNC .FILE_EXISTS_ERROR

        MOV BX, DI
        ; CALL GET_DIRECTORY_SIZE
        XOR CX, CX

.FIND_FREE:
        CMP BYTE[ES:BX], 0
        JE .EXTEND

        CMP BYTE[ES:BX], 0xE5
        JE .FOUND_FREE

        CMP CX, 112
        JAE .DIRECTORY_FULL_ERROR ; <- Zamenji to z smiselno napako.

        ADD BX, 32
        INC CX
        JMP .FIND_FREE

.EXTEND:
        MOV BYTE[ES:BX + 32], 0

.FOUND_FREE:
        PUSH BX
        MOV BX, DI
        POP DI

        ; MOV SI, FILENAME_BUFFER
        MOV CX, 11
        CALL MEMCPY

	XOR CX, CX

; TODO:
; - Cajt nastanka.

	MOV BYTE[ES:DI + 11], DH
	MOV WORD[ES:DI + 20], CX
	MOV WORD[ES:DI + 26], CX
	MOV WORD[ES:DI + 28], CX
	MOV WORD[ES:DI + 30], CX

	JMP .OUT

.FILE_EXISTS_ERROR:
	MOV AL, 0x44
	JMP .ERROR

.DIRECTORY_FULL_ERROR:
	MOV AL, 0x48

.ERROR:
	STC

.OUT:
	POP SI
	POP CX
	RET

; SI <- Path.
; DL <- Drive number. (NE VEČ)
; ES:BX <- Where to load the directory.
; DI <- Location of an 11 byte buffer.
;
; DH -> Error code.
; DI -> The converted entry
CONVERT_LE_AND_TRAVERSE:
	PUSH SI
	PUSH CX
	PUSH DX

	MOV DL, BYTE[DRIVE_NUMBER]
	MOV CX, SI

	CMP BYTE[SI], 0
	JZ .CONVERT_ERROR

	XOR AL, AL
	CALL FINDCHAR

	; SUB SI, 1

	PUSH ES
	MOV AX, DS
	MOV ES, AX

.FIND_SEPERATOR:
	CMP BYTE[SI - 1], '/'
	JE .FOUND_IT
	
	CMP SI, CX
	JE .NO_PATH

	DEC SI
	JMP .FIND_SEPERATOR

.FOUND_IT:
	CALL CONVERT_TO_8_3
	POP ES
	JC .CONVERT_ERROR

	CMP BYTE[SI], 0
	JZ .CONVERT_ERROR

	MOV AH, BYTE[SI]
	MOV BYTE[SI], 0

	PUSH CX 
	MOV CX, SI
	POP SI

	CALL TRAVERSE_PATH
	JC .OUT

	MOV SI, CX
	MOV BYTE[SI], AH
	XOR DH, DH
	JMP .OUT

.CONVERT_ERROR:
	MOV DH, 0x42
	STC
	JMP .OUT

.NO_PATH:
	CALL CONVERT_TO_8_3
	POP ES
	JC .CONVERT_ERROR

	MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]

.OUT:
	MOV CH, DH
	POP DX
	MOV DH, CH
	POP CX
	POP SI
	RET

; SI <- Location of entry in file path.
;
; CX -> Length of the entry.
ENTRY_LEN:
	PUSH AX
	PUSH SI
	XOR CX, CX
	CLD

.LOOP:
	LODSB

	TEST AL, AL
	JZ .OUT

	CMP AL, '/'
	JE .OUT

	INC CX
	JMP .LOOP

.OUT:
	POP SI
	POP AX
	RET

; SI <- Path string.
;
; SI -> Location of next entry in path.
FIND_NEIP:
	PUSH AX
	PUSH CX

	CLD

.LOOP:
	TEST CL, CL
	JZ .OUT

	LODSB

	CMP AL, '/'
	JNE .LOOP

	DEC CL
	JMP .LOOP

.OUT:
	POP CX
	POP AX
	RET

; AX <- First cluster of entry.
; SI <- Array of clusters.
;
; CL -> Index of cluster.
; CF -> Cleared if valid, set otherwise.
IS_PATH_VALID:
	PUSH AX
	PUSH CX
	PUSH DX
	PUSH SI

        MOV DX, AX
	XOR CH, CH
	MOV CL, 8
        CLD

.FIND_LOOP:
        LODSW

        CMP AX, DX
        JE .INVALID

        INC CH

	DEC CL
	JNZ .FIND_LOOP
	JMP .OUT

.INVALID:
	STC

.OUT:
	MOV CL, CH
	POP SI
	POP DX
	POP AX
	MOV CH, AH
	POP AX
	RET

; ES:BX <- Where to load the directory.
; SI <- Path string.
; DL <- Drive number. (LIE)
;
; AX -> First sector of the final directory.
; SI -> Pointer to the entry where the error occured (Points to 0 if all goes well).
; CF -> Cleared on success, set otherwise.
; DH -> Error code.
TRAVERSE_PATH:
	PUSH BX
	PUSH CX
	PUSH DI
	PUSH ES
	PUSH DX

	PUSH DS
	MOV DI, DOS_SEGMENT
	MOV DS, DI

	MOV WORD[DIRECTORY_TARGET_SEGMENT], ES
	MOV WORD[DIRECTORY_TARGET_OFFSET], BX

	MOV ES, DI

	PUSH SI
	MOV DI, TEMP_ARRAY
	MOV SI, FIRST_CLUSTERS
	MOV CX, 17
	CALL MEMCPY
	POP SI

	MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]
	POP DS

	CALL ENTRIES_IN_PATH

.LOAD_LOOP:
	PUSH ES
        MOV DI, DOS_SEGMENT
        MOV ES, DI
        MOV DI, CONVERTED_8_3
        CALL CONVERT_TO_8_3
	POP ES
	PUSH DS
        JC .DIRECTORY_NOT_FOUND

	MOV DI, DOS_SEGMENT
	MOV DS, DI 

	CMP BYTE[SI], '/'
	JNE .NOT_ROOT

	CMP BYTE[SI - 1], '/'
	JE .DIRECTORY_NOT_FOUND

	PUSH ES
	PUSH CX

	MOV AL, 0xFF
	MOV DI, DOS_SEGMENT
	MOV ES, DI
	MOV DI, TEMP_ARRAY
	MOV CX, 16
	CALL MEMSET
	
	MOV BYTE[TEMP_LENGTH], 0

	POP CX
	POP ES

	XOR AX, AX
	JMP .ROOT_DIR

.NOT_ROOT:
	PUSH SI
        MOV SI, CONVERTED_8_3
        CALL FIND_ENTRY
	POP SI
        JC .DIRECTORY_NOT_FOUND

	TEST BYTE[ES:BX + 11], 0x10
        JZ .FILE_NOT_DIRECTORY

        MOV AX, WORD[ES:BX + 26]
	; <-
	CMP BYTE[CONVERTED_8_3], '.'
	JNE .NORMAL

	; JMP .ROOT_DIR
	CMP BYTE[CONVERTED_8_3 + 1], '.'
	JNE .ROOT_DIR

	CALL CLUSTER_BACK
	JMP .ROOT_DIR ; <- Poor naming.

.NORMAL:
	CMP BYTE[TEMP_LENGTH], 8
	JAE .MAX_DEPTH

	CALL CLUSTER_FORWARD
	
.ROOT_DIR:
	MOV BX, DOS_SEGMENT
	MOV ES, BX
	MOV BX, DATA_BUFFER

	MOV DL, BYTE[DRIVE_NUMBER] ; <- When multi drive support arrives. (figured out this is ok)
        CALL LOAD_DIRECTORY
        JC .DISK_ERROR

	POP DS
	CALL NEXT_PATH_ENTRY

	DEC CX
	JNZ .LOAD_LOOP

	PUSH SI
	PUSH DS

	MOV SI, DOS_SEGMENT
	MOV DS, SI

	CALL GET_DIRECTORY_SIZE
	INC CX
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1

	MOV SI, DATA_BUFFER
	MOV DI, WORD[DIRECTORY_TARGET_SEGMENT]
	MOV ES, DI
	MOV DI, WORD[DIRECTORY_TARGET_OFFSET]
	CALL MEMCPY ; Vsebina prejsne se vedno ostane!!!!!!!!!!!111 (ni problem, ampak dobr vedt)

	CMP WORD[DIRECTORY_TARGET_SEGMENT], 0
	JNE .SKIP

	MOV SI, WORD[WORKING_DIRECTORY]
	CMP WORD[DIRECTORY_TARGET_OFFSET], SI
	JNE .SKIP

	MOV SI, TEMP_ARRAY
	MOV DI, DOS_SEGMENT
	MOV ES, DI
	MOV DI, FIRST_CLUSTERS
	MOV CX, 17
	CALL MEMCPY

.SKIP:
	POP DS
	POP SI

	CLC
	JMP .OUT

.DIRECTORY_NOT_FOUND:
	POP DS
	MOV DH, 0x43 ; <- Zamenjaj z pravilno statusno kodo!
	STC
	JMP .OUT

.FILE_NOT_DIRECTORY:
	POP DS
	MOV DH, 0x46 ; <- Zamenjaj z pravilno statusno kodo!
	STC
	JMP .OUT

.DISK_ERROR:
	POP DS
	JMP .OUT

.MAX_DEPTH:
	POP DX
	MOV DH, 0x4A ; <- Zamenjaj z pravilno statusno kodo!
	STC

.OUT:
	MOV CH, DH
	POP DX
	MOV DH, CH
	POP ES
	POP DI
	POP CX
	POP BX
	RET

DIRECTORY_TARGET_SEGMENT: DW 0
DIRECTORY_TARGET_OFFSET: DW 0
DW 0
TEMP_ARRAY: TIMES 8 DW 0xFFFF
TEMP_LENGTH: DB 0

CLUSTER_BACK:
	PUSH BX 
	; MOVZX BX, BYTE[TEMP_LENGTH]
	MOV BL, BYTE[TEMP_LENGTH]
	XOR BH, BH
	DEC BX
	MOV BYTE[TEMP_LENGTH], BL
	SHL BX, 1
	ADD BX, TEMP_ARRAY
	MOV WORD[BX], 0xFFFF
	POP BX
	RET

CLUSTER_FORWARD:
	PUSH BX
	; MOVZX BX, BYTE[TEMP_LENGTH]
	MOV BL, BYTE[TEMP_LENGTH]
	XOR BH, BH
	INC BYTE[TEMP_LENGTH]
	SHL BX, 1
	ADD BX, TEMP_ARRAY
	MOV WORD[BX], AX
	POP BX
	RET

; SI <- Path string.
;
; Mostly to help the user know where he is.
UPDATE_WORKING_DIRECTORY_PATH:
	PUSH AX
	PUSH CX
	PUSH SI
	PUSH DI
	PUSH ES

	CALL ENTRIES_IN_PATH

	MOV DI, DOS_SEGMENT
	MOV ES, DI

.LOOP:
	CMP BYTE[SI], '/'
	JE .CLEAR_PATH

	CMP BYTE[SI], '.'
	JNE .APPEND

	CMP BYTE[SI + 1], '.'
	JNE .CONTINUE

        MOV DI, DIRECTORY_PATH
        ADD DI, WORD[ES:PATH_LENGTH]
        DEC DI

.ERASE_LOOP:
        MOV BYTE[DI], 0
	DEC DI

        CMP BYTE[DI], '/'
        JNE .ERASE_LOOP

        SUB DI, DIRECTORY_PATH - 1
        MOV WORD[ES:PATH_LENGTH], DI
        JMP .CONTINUE

.CLEAR_PATH:
	PUSH CX
	MOV CX, WORD[ES:PATH_LENGTH]

	XOR AL, AL
	MOV DI, DIRECTORY_PATH
	CLD

.CLEAR_LOOP:
	STOSB
	LOOP .CLEAR_LOOP

	MOV BYTE[ES:DIRECTORY_PATH], '/'
	MOV WORD[ES:PATH_LENGTH], 1
	POP CX
	JMP .CONTINUE
	
.APPEND:
	PUSH CX
	MOV DI, SI
	CALL NEXT_PATH_ENTRY
	MOV CX, SI
	SUB CX, DI
	DEC CX

	MOV SI, DI
        MOV DI, DIRECTORY_PATH
        ADD DI, WORD[ES:PATH_LENGTH]
        CALL MEMCPY

        ADD DI, CX
        MOV BYTE[DI], '/'
        INC CX
        ADD WORD[ES:PATH_LENGTH], CX
	POP CX

.CONTINUE:
	CALL NEXT_PATH_ENTRY
	LOOP .LOOP

.OUT:
	POP ES
	POP DI
	POP SI
	POP CX
	POP AX
	RET

; ES:BX <- Location of directory.
;
; CX -> The size of the directory in entries.
;
; Returns the number of entries in a directory (includes empty entries).
GET_DIRECTORY_SIZE:
	PUSH BX
	XOR CX, CX

.LOOP:
	CMP BYTE[ES:BX], 0
	JZ .OUT

	ADD BX, 32

	INC CX
	JMP .LOOP

.OUT:
	POP BX
	RET

; SI <- Path location.
;
; CX -> Number of entries.
;
; If an absolute path is given, the root directory counts as an entry.
ENTRIES_IN_PATH:
	PUSH AX
	PUSH SI
	MOV CX, 1
	CLD

.LOOP:
	LODSB

	CMP BYTE[SI], 0
	JZ .OUT

	CMP AL, '/'
	JNE .LOOP

	INC CX
	JMP .LOOP

.OUT:
	POP SI
	POP AX
	RET

; SI <- Where to search.
;
; SI -> Location of next entry.
NEXT_PATH_ENTRY:
	PUSH AX
	CLD

.LOOP:
	LODSB

	TEST AL, AL
	JZ .OUT

	CMP AL, '/'
	JNE .LOOP

.OUT:
	POP AX
	RET

; AL <- Character to find.
; SI <- String.
;
; SI -> Character location.
FINDCHAR:
	CMP BYTE[SI], AL
	JE .OUT

	INC SI
	JMP FINDCHAR

.OUT:
	RET

; AX <- First sector of the directory.
; ES:BX <- Where to load the directory.
; DL <- Drive number. (CURRENTLY A LIE)
;
; DH -> BIOS error code.
LOAD_DIRECTORY:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI

	MOV DL, BYTE[DRIVE_NUMBER]

	TEST AX, AX
	JZ .ROOT_DIRECTORY

.LOOP:
	CALL READ_DATA
	JC .OUT

	CALL GET_NEXT_CLUSTER
	CMP AX, 0xFF8
	JL .LOOP

	XOR DH, DH
	JMP .OUT

.ROOT_DIRECTORY:
	PUSH DX
	MOV AL, BYTE[NUMBER_OF_FAT]
	XOR AH, AH
        MUL WORD[SECTORS_PER_FAT]
        ADD AX, WORD[RESERVED_SECTORS]
	POP DX

        MOV CX, WORD[ROOT_ENTRIES]
        ADD CX, 15
	SHR CX, 1
	SHR CX, 1
	SHR CX, 1
	SHR CX, 1

        CALL READ_DISK

.OUT:
	POP DI
	POP SI
	MOV AH, DH
	POP DX
	MOV DH, AH
	POP CX
	POP BX
	POP AX
	RET

; AX <- First sector of the directory.
; ES:BX <- Where the directory is located.
; CX <- Size of the directory (in entries).
; DL <- Drive number. (NE VEČ)
STORE_DIRECTORY:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI

	MOV DL, BYTE[DRIVE_NUMBER]

	TEST AX, AX
	JZ .ROOT_DIRECTORY

	; MOV CX, WORD[DIRECTORY_SIZE]
	; MOV SI, WORD[CURRENT_DIRECTORY]

	; PUSH DS
	; XOR DI, DI
	; MOV DS, DI

	; MOV DI, CX
	; SHL DI, 5
	
	; ADD SI, DI
	; MOV BYTE[SI], 0
	; POP DS

.LOOP:
	CMP AX, 0xFF8
	JL .CONTINUE

        CALL GET_FREE_CLUSTER
        JC .OUT ; <- Za en kurac odgovor.

	PUSH DX
        MOV DX, 0xFFF
        CALL WRITE_CLUSTER

        MOV DX, AX
        MOV AX, WORD[INT_WRITE_LAST]
        CALL WRITE_CLUSTER

        MOV AX, DX
	POP DX

.CONTINUE:
	CALL WRITE_DATA
	JC .OUT

	MOV WORD[INT_WRITE_LAST], AX
	CALL GET_NEXT_CLUSTER

	SUB CX, 16
	JNC .LOOP
	CLC
	JMP .OUT

.ROOT_DIRECTORY:
	PUSH DX
        ; MOVZX AX, BYTE[NUMBER_OF_FAT]
	MOV AL, BYTE[NUMBER_OF_FAT]
	XOR AH, AH
        MUL WORD[SECTORS_PER_FAT]
        ADD AX, WORD[RESERVED_SECTORS]
	POP DX

        MOV CX, WORD[ROOT_ENTRIES]
        ADD CX, 15
        ; SHR CX, 4
	SHR CX, 1
	SHR CX, 1
	SHR CX, 1
	SHR CX, 1

        CALL WRITE_DISK

.OUT:
	POP DI
	POP SI
	POP DX
	POP CX
	POP BX
	POP AX
	RET

; AL <- Character.
;
; AL -> Character converted to uppercase.
TO_UPPER:
        CMP AL, 'a'
        JL .OUT

        CMP AL, 'z'
        JG .OUT

        SUB AL, 32

.OUT:
        RET

; DL <- Drive number.
UPDATE_FS_WRITE_INT:
	PUSH AX
	PUSH CX
	PUSH ES
	PUSH BX

        CALL STORE_FAT

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]

	MOV AX, WORD[INT_DIRECTORY_FIRST_SECTOR] ; Pozor
	MOV CX, WORD[INT_DIRECTORY_SIZE]
	CALL STORE_DIRECTORY

	POP BX
	POP ES
	POP CX
	POP AX
	RET

; DL <- Drive number.
; ES:BX <- FAT memory address.
;
; DH -> Error code.
LOAD_FAT:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI
        PUSH ES

        MOV CX, WORD[SECTORS_PER_FAT]

        ; XOR BX, BX
        ; MOV ES, BX
        ; MOV BX, FILESYSTEM

        MOV AX, WORD[RESERVED_SECTORS]
        ; MOV DL, BYTE[DRIVE_NUMBER]
        MOV DH, BYTE[NUMBER_OF_FAT]

.LOAD_LOOP:
        CALL READ_DISK
	JC .OUT

        ADD AX, CX

        DEC DH
        JNZ .LOAD_LOOP
	CLC

.OUT:
        POP ES
	POP DI
	POP SI
	MOV AH, DH
	POP DX
	MOV DH, AH
	POP CX
	POP BX
	POP AX
        RET

; DL <- Drive number.
;
; DH -> Error code.
STORE_FAT:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI
        PUSH ES

        MOV CX, WORD[SECTORS_PER_FAT]

        XOR BX, BX
        MOV ES, BX
        MOV BX, FILESYSTEM

        MOV AX, WORD[RESERVED_SECTORS]
        ; MOV DL, BYTE[DRIVE_NUMBER]
        MOV CH, BYTE[NUMBER_OF_FAT]

.STORE_LOOP:
        CALL WRITE_DISK

        ADD AX, CX

        DEC CH
        JNZ .STORE_LOOP

        POP ES
	POP DI
	POP SI
	MOV AH, DH
	POP DX
	MOV DH, AH
	POP CX
	POP BX
	POP AX
        RET

; SI <- Filename to convert.
; ES:DI <- Pointer to where to store the string.
;
; CF -> Cleared if successful.
CONVERT_TO_8_3:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI

        MOV AL, ' '
        MOV CX, 11
        CALL MEMSET

	CMP BYTE[SI], '.' ; If the first character is a dot it means it is one of those special entries.
	JE .FIRST_DOT

        MOV BX, DI

        CLC
        MOV CX, 8

.LOOP:
        LODSB
	CALL TO_UPPER

        CMP AL, '.'
        JE .DOT

        CMP AL, 0x00
        JE .OUT

	CMP AL, '/'
	JE .OUT

        CMP CX, 0
        JNZ .STORE_BYTE

        STC
        JMP .OUT

.STORE_BYTE:
        STOSB
        DEC CX
        JMP .LOOP

.DOT:
        MOV DI, BX
        ADD DI, 8
        MOV CX, 3
        JMP .LOOP

.FIRST_DOT:
	MOV CX, 11

.LOOPCIC:
	CMP BYTE[SI], 0
	JZ .OUT
	
	CMP BYTE[SI], '/'
	JE .OUT

	LODSB
	STOSB

	LOOP .LOOPCIC

.OUT:
	POP DI
	POP SI
	POP DX
	POP CX
	POP BX
	POP AX
        RET

; DX <- File size.
PRINT_FILE_SIZE:
        PUSH AX
        PUSH CX
        PUSH DX
        PUSH SI

        CALL GET_FILE_SIZE

        MOV AH, 0x03
        INT 0x20

	MOV AH, 0x01
	MOV SI, KIB_SUFFIX
	MOV CX, 4
	INT 0x20

        POP SI
        POP DX
        POP CX
        POP AX
        RET

KIB_SUFFIX: DB " KiB"

; ES:BX <- Pointer to file entry.
;
; DX -> File size in KiB.
GET_FILE_SIZE:
        PUSH AX

        MOV DX, WORD[ES:BX + 28]
        ADD DX, 1023

        MOV AX, WORD[ES:BX + 30]
        ADC AX, 0
        ; SHL AX, 6
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1

        ; SHR DX, 10
	ROL DX, 1
	ROL DX, 1
	ROL DX, 1
	ROL DX, 1
	ROL DX, 1
	ROL DX, 1
	AND DX, 0x003F
	
        ADD DX, AX

        POP AX
        RET

; Prints a new line and a carrige return.
NLCR:
        PUSH AX
	PUSH BX

        MOV AH, 0x0E
        MOV AL, 0x0A
	MOV BX, 7
        INT 0x10
	MOV AH, 0x0E
        MOV AL, 0x0D
        INT 0x10

	POP BX
        POP AX
        RET

; AL <- Character to print out.
PUTCHAR:
        PUSH AX
	PUSH BX

        MOV AH, 0x0E
	MOV BX, 7
        INT 0x10

	POP BX
        POP AX
        RET

; SI <- Pointer to first string.
; DI <- Pointer to second string.
;
; ZF <- Set if strings are equal.
STRCMP:
        PUSH AX
        PUSH SI
        PUSH DI

.CMP_LOOP:
        LODSB
        CMP BYTE[DI], AL
        JNE .OUT

        INC DI

        TEST AL, AL
        JNZ .CMP_LOOP

.OUT:
        POP DI
        POP SI
        POP AX
        RET

; SI <- Pointer to string.
;
; CX -> String length.
STRLEN:
        PUSH SI
        XOR CX, CX

.LOOP:
        LODSB
        TEST AL, AL
        JZ .OUT
        INC CX
        JMP .LOOP

.OUT:
        POP SI
        RET

; ES:BX <- Pointer to file entry.
PRINT_FILENAME:
        PUSH AX
        PUSH BX
        PUSH CX

        MOV CX, 11

.PRINT_LOOP:
        MOV AL, BYTE[ES:BX]
	CALL PUTCHAR

        CMP CX, 4
        JNE .NOT_DOT

        MOV AL, '.'
	CALL PUTCHAR

.NOT_DOT:
        INC BX
        LOOP .PRINT_LOOP

.OUT:
        POP CX
        POP BX
        POP AX
        RET

; ES:BX <- Start of directory.
; SI <- File name to find.
;
; CF -> Set if not found.
; BX -> Location of entry.
FIND_ENTRY:
        CLC

.LOOP:
        CMP BYTE[ES:BX], 0
        JZ .ERROR

        CALL FILENAMECMP
        JE .OUT

        ADD BX, 32
        JMP .LOOP

.ERROR:
        STC

.OUT:
        RET

; ES:BX <- File name in directory entry.
; SI <- File name to compare to.
;
; ZF -> Set if equal.
FILENAMECMP:
        PUSH AX
        PUSH BX
        PUSH CX
        PUSH SI

        MOV CX, 11

.LOOP:
        LODSB

        CMP AL, BYTE[ES:BX]
        JNE .OUT

        INC BX
        LOOP .LOOP

        XOR AX, AX

.OUT:
        POP SI
        POP CX
        POP BX
        POP AX
        RET

; AL <- Value to set to.
; ES:DI <- Pointer to buffer.
; CX <- Number of bytes to set.
MEMSET:
        PUSH CX
        PUSH DI

.LOOP:
        TEST CX, CX
        JZ .OUT
        MOV BYTE[ES:DI], AL
        INC DI 
        LOOP .LOOP

.OUT:
        POP DI
        POP CX
        RET

; SI <- Source buffer.
; ES:DI <- Destination buffer.
; CX <- Number of bytes to copy.
MEMCPY:
        PUSH AX
        PUSH CX
        PUSH SI
        PUSH DI
	CLD

        TEST CX, CX
        JZ .OUT

.LOOP:
        LODSB
        STOSB
        LOOP .LOOP

.OUT:
        POP DI
        POP SI
        POP CX
        POP AX
        RET

; AX <- Current cluster.
; ES:BX <- Source buffer.
WRITE_DATA:
        PUSH AX
        PUSH CX
        PUSH DX

	PUSH DX
        SUB AX, 2
        ; MOVZX CX, BYTE[SECTORS_PER_CLUSTER]
	MOV CL, BYTE[SECTORS_PER_CLUSTER]
	XOR CH, CH
        MUL CX 
	POP DX

        ADD AX, WORD[DATA_AREA_BEGIN]
        MOV DL, BYTE[DRIVE_NUMBER]
        CALL WRITE_DISK

	MOV AH, DH
        POP DX
	MOV DH, AH
        POP CX
        POP AX
        RET

; AX <- Current cluster.
; ES:BX <- Destination buffer.
;
; DH -> BIOS error code.
READ_DATA:
        PUSH AX
        PUSH CX
        PUSH DX

	PUSH DX
        SUB AX, 2
        ; MOVZX CX, BYTE[SECTORS_PER_CLUSTER]
	MOV CL, BYTE[SECTORS_PER_CLUSTER]
	XOR CH, CH
        MUL CX 
	POP DX

        ADD AX, WORD[DATA_AREA_BEGIN]
        MOV DL, BYTE[DRIVE_NUMBER]
        CALL READ_DISK

	; SIMULACIJA NAPAKE
	; MOV DH, 0x10
	; STC

	MOV AH, DH
        POP DX
	MOV DH, AH
        POP CX
        POP AX
        RET

; AX <- Cluster to write to.
; DX <- Value to write.
WRITE_CLUSTER:
        PUSH ES
        PUSH BX
        PUSH DX

        MOV BX, FILESYSTEM >> 4
        MOV ES, BX
        MOV BX, AX

        SHR BX, 1
        ADD BX, AX

        TEST AX, 1
        JZ .EVEN_CLUSTER

        ; SHL DX, 4
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
        AND WORD[ES:BX], 0x000F
        OR WORD[ES:BX], DX
        JMP .ODD_CLUSTER

.EVEN_CLUSTER:
        AND WORD[ES:BX], 0xF000
        OR WORD[ES:BX], DX

.ODD_CLUSTER:
        POP DX
        POP BX
        POP ES
        RET

; AX -> Free cluster location.
;
; CF -> Set if out of space, cleared otherwise.
GET_FREE_CLUSTER:
        PUSH ES
        PUSH BX

        MOV AX, WORD[LAST_ALLOCATED_CLUSTER]
        INC AX

        MOV BX, FILESYSTEM >> 4
        MOV ES, BX

.SEARCH:
        AND AX, 0xFFF

        CMP AX, WORD[LAST_ALLOCATED_CLUSTER]
        JE .OUT_OF_SPACE

        MOV BX, AX
        SHR BX, 1
        ADD BX, AX

        PUSH AX
        MOV AX, WORD[ES:BX]
        TEST AX, 1
        JZ .EVEN_CLUSTER

        AND AX, 0x0FFF
        POP AX
        JZ .OUT
        INC AX
        JMP .SEARCH

.EVEN_CLUSTER:
        ; SHR AX, 4
	SHR AX, 1
	SHR AX, 1
	SHR AX, 1
	SHR AX, 1
        POP AX
        JZ .OUT
        INC AX
        JMP .SEARCH

.OUT:
        MOV WORD[LAST_ALLOCATED_CLUSTER], AX

        POP BX
        POP ES
        RET

.OUT_OF_SPACE:
        STC
        POP BX
        POP ES
        RET

LAST_ALLOCATED_CLUSTER: DW 0

; AX <- Current cluster.
;
; AX -> Next cluster.
GET_NEXT_CLUSTER:
        PUSH ES
        PUSH BX

        MOV BX, FILESYSTEM >> 4
        MOV ES, BX
        MOV BX, AX
        SHR BX, 1
        ADD BX, AX

        TEST AX, 1
        MOV AX, WORD[ES:BX]
        JZ .EVEN_CLUSTER

        ; SHR AX, 4
	SHR AX, 1
	SHR AX, 1
	SHR AX, 1
	SHR AX, 1
        JMP .ODD_CLUSTER

.EVEN_CLUSTER:
        AND AX, 0x0FFF

.ODD_CLUSTER:
        POP BX
        POP ES
        RET

; AX <- LBA value.
; CL <- Number of sectors to write.
; DL <- Drive number.
; ES:BX <- Pointer to buffer.
;
; DH -> BIOS error code.
WRITE_DISK:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI
        PUSH ES

	XOR CH, CH
	MOV DI, CX

.WRITE_LOOP:
        CALL LBA_TO_CHS
        CALL WRITE_CHS
        JC .RETURN

        MOV SI, ES
        ADD SI, 32
        MOV ES, SI

        INC AX
        DEC DI
        JNZ .WRITE_LOOP

	XOR AH, AH

.RETURN:
        POP ES
	POP DI
	POP SI
	POP DX
	MOV DH, AH
	POP CX
	POP BX
	POP AX
        RET

; ES:BX <- Pointer to buffer to be written.
; CX[0:5] <- Sector number.
; CX[6:15] <- Track/Cylinder.
; DH <- Head number.
; DL <- Drive number.
;
; AH -> BIOS error code.
WRITE_CHS:
	PUSH DX
        PUSH AX
        PUSH DI
        MOV DI, 3

	CMP BYTE[DISKETTE_CHANGED], 1
	JE .DISKETTE_CHANGED

.WRITE_LOOP:
        STC
        MOV AH, 0x03
        MOV AL, 1
        INT 0x13
        JNC .OUT

	CMP AH, 0x06
	JE .DISKETTE_CHANGED

        DEC DI
        JNZ .WRITE_LOOP

.OUT_CARRY:
        STC

.OUT:
        POP DI
	MOV DH, AH
        POP AX
	MOV AH, DH
	POP DX
        RET

.DISKETTE_CHANGED:
	CMP DL, BYTE[DRIVE_NUMBER]
	JNE .WRITE_LOOP

	CALL RELOAD_FILESYSTEM
	JMP .OUT_CARRY

; AX <- LBA value.
; CL <- Number of sectors to read.
; DL <- Drive number.
; ES:BX <- Pointer to buffer.
;
; DH -> BIOS error code.
READ_DISK:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI
        PUSH ES

	XOR CH, CH
	MOV DI, CX

.READ_LOOP:
        CALL LBA_TO_CHS
        CALL READ_CHS
        JC .RETURN

        MOV SI, ES
        ADD SI, 32
        MOV ES, SI
        INC AX
        DEC DI
        JNZ .READ_LOOP

	XOR AH, AH

.RETURN:
        POP ES
	POP DI
	POP SI
	POP DX
	MOV DH, AH
	POP CX
	POP BX
	POP AX
        RET

; ES:BX <- Pointer to target buffer.
; CX[0:5] <- Sector number.
; CX[6:15] <- Track/Cylinder.
; DH <- Head number.
; DL <- Drive number.
;
; AH -> BIOS error code.
READ_CHS:
	PUSH DX
        PUSH AX
        PUSH DI
        MOV DI, 3

	CMP BYTE[DISKETTE_CHANGED], 1
	JE .DISKETTE_CHANGED

.READ_LOOP:
        STC
        MOV AH, 0x02
        MOV AL, 1
        INT 0x13
        JNC .OUT

	CMP AH, 0x06
	JE .DISKETTE_CHANGED

        DEC DI
        JNZ .READ_LOOP

.OUT_CARRY:
        STC

.OUT:
        POP DI
	MOV DH, AH
        POP AX
	MOV AH, DH
	POP DX
        RET

.DISKETTE_CHANGED:
	CMP DL, BYTE[DRIVE_NUMBER]
	JNE .READ_LOOP

	CALL RELOAD_FILESYSTEM
	JMP .OUT_CARRY

; ljubi bog to je katastrofa
; DL <- Drive number.
;
; Reloads the current filesystem information in case of diskette change.
RELOAD_FILESYSTEM:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI
	PUSH DS
	PUSH ES

	MOV BYTE[DISKETTE_CHANGED], 0

        XOR AH, AH
        INT 0x13
        JC .ERROR

        MOV AL, 1
        MOV CX, 1
        XOR DH, DH
	MOV BX, DOS_SEGMENT
	MOV ES, BX
        MOV BX, BPB 
	CALL READ_CHS
        JC .ERROR

	MOV BYTE[DRIVE_NUMBER], DL

	XOR BX, BX
	MOV ES, BX
	MOV BX, FILESYSTEM
        CALL LOAD_FAT
        JC .ERROR

        ; MOV BYTE[DRIVE_NUMBER], DL

        XOR DX, DX
        ; MOVZX AX, BYTE[SECTORS_PER_CLUSTER]
	MOV AL, BYTE[SECTORS_PER_CLUSTER]
	XOR AH, AH
        MUL WORD[BYTES_PER_SECTOR]
        MOV WORD[BYTES_PER_CLUSTER], AX

        XOR AH, AH
        MOV AL, BYTE[NUMBER_OF_FAT]
        MUL WORD[SECTORS_PER_FAT]

        MOV CX, WORD[SECTORS_PER_FAT]
        ; SHL CX, 9
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
        ADD AX, WORD[RESERVED_SECTORS]

        ADD CX, FILESYSTEM
        MOV WORD[WORKING_DIRECTORY], CX

        MOV BX, WORD[ROOT_ENTRIES]
        ; SHL BX, 5
        ; ADD BX, 511
        ; SHR BX, 9
	ADD BX, 15
	SHR BX, 1
	SHR BX, 1
	SHR BX, 1
	SHR BX, 1
        ADD AX, BX

        MOV WORD[DATA_AREA_BEGIN], AX
        MOV WORD[LAST_ALLOCATED_CLUSTER], 0
	MOV WORD[DIRECTORY_RET_FIRST_SECTOR], 0

        MOV AH, 0x12
        MOV SI, ROOT_DIRECTORY_PATH
        INT 0x20

	TEST AL, AL
	JNZ .ERROR

        XOR BX, BX
        MOV ES, BX
        MOV BX, WORD[WORKING_DIRECTORY]
        CALL GET_DIRECTORY_SIZE

        MOV WORD[DIRECTORY_SIZE], CX
	MOV WORD[DIRECTORY_RET_SIZE], CX

        MOV AL, BYTE[SECTORS_PER_CLUSTER]
        ; SHL AX, 9
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1
	SHL AX, 1
        CALL LOG2
        MOV BYTE[LOG2_CLUSTER_SIZE], CL

	XOR AL, AL
	MOV DI, DIRECTORY_PATH
	MOV CX, DIRECTORY_INFO_END - DIRECTORY_PATH
	CALL MEMSET

	MOV BYTE[SI], '/'
	MOV WORD[PATH_LENGTH], 1

	PUSH CX
	NOT AL
	MOV DI, FIRST_CLUSTERS
	MOV CX, 16
	CALL MEMSET
	POP CX

	MOV SI, DIRECTORY_PATH
	MOV DI, DOS_SEGMENT
	MOV ES, DI
	MOV DI, PATH_INFO_BUFFER
	CALL MEMCPY

	CLC

.OUT:
	POP ES
	POP DS
	POP DI
	POP SI
	POP DX
	POP CX
	POP BX
	POP AX
	RET

.ERROR:
	MOV BYTE[DISKETTE_CHANGED], 1
	STC
	JMP .OUT

; AX <- LBA value.
;
; CX[0:5] -> Sector number.
; CX[6:15] -> Track/Cylinder.
; DH -> Head number.
LBA_TO_CHS:
        PUSH AX
        PUSH DX

        XOR DX, DX
        DIV WORD[SECTORS_PER_TRACK]
        INC DX
        MOV CL, DL ; Get the sector number.

        XOR DX, DX
        DIV WORD[HEAD_COUNT]
        ; SHL DX, 8 ; Get the head number.
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1

        MOV CH, AL
        ; SHL AH, 6
	ROR AH, 1
	ROR AH, 1
	AND AH, 0xC0
        OR CL, AH ; Get the number of tracks/cylinders.

        MOV AL, DH
        POP DX
        MOV DH, AL
        POP AX
        RET

; Floppy drives sometimes spit out an error if you don't reset after fast consecutive read/writes.
RESET_DISK:
        PUSH AX
        PUSH DX

        MOV AH, 0x00
        MOV DL, BYTE[DRIVE_NUMBER]
        INT 0x13

        POP DX
        POP AX
        RET

; AX <- Value.
;
; CL -> Result.
LOG2:
        PUSH AX

        XOR CL, CL

.LOOP:
        SHR AX, 1

        TEST AX, AX
        JZ .OUT
        INC CL
        JMP .LOOP

.OUT:
        POP AX
        RET
