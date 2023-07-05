; PROCEDURES
; ----------

; AX <- First sector of the directory.
LOAD_DIRECTORY:
	PUSH ES
	PUSH BX

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[CURRENT_DIRECTORY]

	TEST AX, AX
	JZ .ROOT_DIRECTORY

	CALL READ_DATA
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
	POP BX
	POP ES
	RET

; AX <- First sector of the directory.
STORE_DIRECTORY:
	PUSH ES
	PUSH BX

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[CURRENT_DIRECTORY]

	TEST AX, AX
	JZ .ROOT_DIRECTORY

	CALL WRITE_DATA
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
	POP BX
	POP ES
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
        CALL STORE_FAT

	MOV AX, WORD[CURRENT_DIRECTORY_FIRST_SECTOR]
	CALL STORE_DIRECTORY
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

; ES:BX <- Pointer to file entry.
PRINT_FILE_SIZE:
        PUSH AX
        PUSH CX
        PUSH DX
        PUSH SI

        CALL GET_FILE_SIZE

        MOV AH, 0x03
        INT 0x80

        MOV AL, 'K'
        CALL PUTCHAR

        POP SI
        POP DX
        POP CX
        POP AX
        RET

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

        ; CMP AL, 0x00
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
