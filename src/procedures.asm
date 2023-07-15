; PROCEDURES
; ----------

; Helper procedure to parse the errors returned by the TRAVERSE_PATH procedure.
PATH_ERRORS:
	SHR AX, 12

        CMP AX, 1
        JE DIR_NOT_FOUND

        CMP AX, 2
        JE FILE_NOT_DIRECTORY

        JMP READ_ERROR

; ES:BX <- Where to load the directory.
; SI <- Path string.
;
; AX -> First sector of the final directory.
; SI -> Pointer to the entry where the error occured (Points to 0 if all goes well).
; CF -> Cleared on success, set otherwise.
; AX[12:16] -> Error codes (0 if success).
; Errors:
; 1 - An entry in the path does not exist.
; 2 - The entry exists but is not a directory.
; 3 - An error occured while trying to read the directory.
TRAVERSE_PATH:
	PUSH BX
	PUSH CX
	; PUSH SI
	PUSH DI
	PUSH ES

	PUSH DS
	MOV DI, DOS_SEGMENT
	MOV DS, DI

	MOV WORD[DIRECTORY_TARGET_SEGMENT], ES
	MOV WORD[DIRECTORY_TARGET_OFFSET], BX

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

.ROOT_DIR:
	MOV BX, DOS_SEGMENT
	MOV ES, BX
	MOV BX, DATA_BUFFER

	CMP CX, 1
	JNE .LOAD

	MOV BX, WORD[DIRECTORY_TARGET_SEGMENT]
	MOV ES, BX
	MOV BX, WORD[DIRECTORY_TARGET_OFFSET]

.LOAD:
        CALL LOAD_DIRECTORY
        JC .READ_ERROR

	POP DS
	CALL NEXT_PATH_ENTRY

	LOOP .LOAD_LOOP

	CLC
	JMP .OUT

.DIRECTORY_NOT_FOUND:
	POP DS
	OR AX, 0x1000
	STC
	JMP .OUT

.FILE_NOT_DIRECTORY:
	POP DS
	OR AX, 0x2000
	STC
	JMP .OUT

.READ_ERROR:
	POP DS
	OR AX, 0x3000

.OUT:
	POP ES
	POP DI
	; POP SI
	POP CX
	POP BX
	RET

DIRECTORY_TARGET_SEGMENT: DW 0
DIRECTORY_TARGET_OFFSET: DW 0

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
; SI -> Location of seperator.
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
; SI <- Where to search the char.
;
; CX -> Offset of the character in bytes.
FINDCHAR:
	PUSH SI

.LOOP:
	CMP BYTE[SI], AL
	JE .OUT

	INC SI
	JMP .LOOP

.OUT:
	MOV CX, SI
	POP SI
	SUB CX, SI
	RET

; AX <- First sector of the directory.
; ES:BX <- Where to load the directory.
LOAD_DIRECTORY:
	PUSHA

	TEST AX, AX
	JZ .ROOT_DIRECTORY

.LOOP:
	CALL READ_DATA

	CALL GET_NEXT_CLUSTER
	CMP AX, 0xFF8
	JL .LOOP
	JMP .OUT

.ROOT_DIRECTORY:
	XOR DX, DX

        MOVZX AX, BYTE[NUMBER_OF_FAT]
        MUL WORD[SECTORS_PER_FAT]
        ADD AX, WORD[RESERVED_SECTORS]

        MOV DX, WORD[ROOT_ENTRIES]
        ADD DX, 15
        SHR DX, 4

        MOV CL, DL
        MOV DL, BYTE[DRIVE_NUMBER]

        CALL READ_DISK

.OUT:
	POPA
	RET

; AX <- First sector of the directory.
; ES:BX <- Where the directory is located.
; CX <- Size of the directory (in entries).
STORE_DIRECTORY:
	PUSHA

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

        MOV DX, 0xFFF
        CALL WRITE_CLUSTER

        MOV DX, AX
        MOV AX, WORD[INT_WRITE_LAST]
        CALL WRITE_CLUSTER

        MOV AX, DX

.CONTINUE:
	CALL WRITE_DATA

	MOV WORD[INT_WRITE_LAST], AX
	CALL GET_NEXT_CLUSTER

	SUB CX, 16
	JNC .LOOP
	JMP .OUT

.ROOT_DIRECTORY:
        XOR DX, DX

        MOVZX AX, BYTE[NUMBER_OF_FAT]
        MUL WORD[SECTORS_PER_FAT]
        ADD AX, WORD[RESERVED_SECTORS]

        MOV DX, WORD[ROOT_ENTRIES]
        ADD DX, 15
        SHR DX, 4

        MOV CL, DL
        MOV DL, BYTE[DRIVE_NUMBER]

        CALL WRITE_DISK

.OUT:
	POPA
	RET

; Turns on the PC speaker.
SPK_ON:
        PUSH AX
        IN AL, 0x61
        OR AL, 3
        OUT 0x61, AL
        POP AX
        RET

; Turns off the PC speaker.
SPK_OFF:
        PUSH AX
        IN AL, 0x61
        AND AL, 0xFC
        OUT 0x61, AL
        POP AX
        RET

; BL <- Value to print.
PUTH8:
        PUSH AX
        PUSH CX
        MOV AH, 0x0E
        MOV CX, 2

.LOOP:
        ROL BL, 4
        MOV AL, BL
        AND AL, 0x0F

        CMP AL, 10
        SBB AL, 0x69
        DAS

        INT 0x10

        DEC CX
        JNZ .LOOP

        POP CX
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

UPDATE_FS:
	PUSH AX
	PUSH CX
	PUSH ES
	PUSH BX

        CALL STORE_FAT

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]

	MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
	MOV CX, WORD[DIRECTORY_SIZE]
	CALL STORE_DIRECTORY

	POP BX
	POP ES
	POP CX
	POP AX
	RET

STORE_FAT:
        PUSHA
        PUSH ES

        MOV CX, WORD[SECTORS_PER_FAT]

        XOR BX, BX
        MOV ES, BX
        MOV BX, FILESYSTEM

        MOV AX, WORD[RESERVED_SECTORS]
        MOV DL, BYTE[DRIVE_NUMBER]
        MOV DH, BYTE[NUMBER_OF_FAT]

.STORE_LOOP:
        CALL WRITE_DISK

        ADD AX, CX

        DEC DH
        JNZ .STORE_LOOP

        POP ES
        POPA
        RET

; SI <- Filename to convert.
; ES:DI <- Pointer to where to store the string.
;
; CF -> Cleared if successful.
CONVERT_TO_8_3:
        PUSHA

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
	LODSB
	STOSB

	CMP BYTE[SI], '.'
	CLC
	JNE .OUT

	LODSB
	STOSB

.OUT:
        POPA
        RET

; DX <- File size.
PRINT_FILE_SIZE:
        PUSH AX
        PUSH CX
        PUSH DX
        PUSH SI

        CALL GET_FILE_SIZE

        MOV AH, 0x03
        INT 0x80

	MOV AH, 0x01
	MOV SI, KIB_SUFFIX
	MOV CX, 4
	INT 0x80

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
        SHL AX, 6

        SHR DX, 10
        ADD DX, AX

        POP AX
        RET

; Prints a new line and a carrige return.
NLCR:
        PUSH AX

        MOV AH, 0x0E
        MOV AL, 0x0A
        INT 0x10
        MOV AL, 0x0D
        INT 0x10

        POP AX
        RET

; AL <- Character to print out.
PUTCHAR:
        PUSH AX

        MOV AH, 0x0E
        INT 0x10

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

        MOV AH, 0x0E
        MOV CX, 11

.PRINT_LOOP:
        MOV AL, BYTE[ES:BX]
        INT 0x10

        CMP CX, 4
        JNE .NOT_DOT

        MOV AL, '.'
        INT 0x10

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

        SUB AX, 2
        MOVZX CX, BYTE[SECTORS_PER_CLUSTER]
        MUL CX 

        ADD AX, WORD[DATA_AREA_BEGIN]
        MOV CL, BYTE[SECTORS_PER_CLUSTER]
        MOV DL, BYTE[DRIVE_NUMBER]
        CALL WRITE_DISK

        POP DX
        POP CX
        POP AX
        RET

; AX <- Current cluster.
; ES:BX <- Destination buffer.
READ_DATA:
        PUSH AX
        PUSH CX
        PUSH DX

        SUB AX, 2
        MOVZX CX, BYTE[SECTORS_PER_CLUSTER]
        MUL CX 

        ADD AX, WORD[DATA_AREA_BEGIN]
        MOV CL, BYTE[SECTORS_PER_CLUSTER]
        MOV DL, BYTE[DRIVE_NUMBER]
        CALL READ_DISK

        POP DX
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

        SHL DX, 4
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
        SHR AX, 4
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

        SHR AX, 4
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
WRITE_DISK:
        PUSHA
        PUSH ES

        MOVZX DI, CL

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

.RETURN:
        POP ES
        POPA
        RET

; ES:BX <- Pointer to buffer to be written.
; CX[0:5] <- Sector number.
; CX[6:15] <- Track/Cylinder.
; DH <- Head number.
; DL <- Drive number.
WRITE_CHS:
        PUSH DI
        MOV DI, 3

.READ_LOOP:
        STC
        PUSH AX
        MOV AH, 0x03
        MOV AL, 1
        INT 0x13
        POP AX
        JNC .OUT

        DEC DI
        JNZ .READ_LOOP
        STC

.OUT:
        POP DI
        RET

; AX <- LBA value.
; CL <- Number of sectors to read.
; DL <- Drive number.
; ES:BX <- Pointer to buffer.
READ_DISK:
        PUSHA
        PUSH ES

        MOVZX DI, CL

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

.RETURN:
        POP ES
        POPA
        RET

; ES:BX <- Pointer to target buffer.
; CX[0:5] <- Sector number.
; CX[6:15] <- Track/Cylinder.
; DH <- Head number.
; DL <- Drive number.
READ_CHS:
        PUSH DI
        MOV DI, 3

.READ_LOOP:
        STC
        PUSH AX
        MOV AH, 0x02
        MOV AL, 1
        INT 0x13
        POP AX
        JNC .OUT

        DEC DI
        JNZ .READ_LOOP
        STC

.OUT:
        POP DI
        RET

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
        SHL DX, 8 ; Get the head number.

        MOV CH, AL
        SHL AH, 6
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
