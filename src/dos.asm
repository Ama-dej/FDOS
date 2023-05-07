[BITS 16]
[ORG 0x0000]
%INCLUDE "src/locations.h"

	MOV WORD[CURRENT_DIRECTORY], DX
	MOV DX, DI
	MOV WORD[DATA_AREA_BEGIN], DX

	XOR AX, AX
	MOV SS, AX
	MOV SP, 0xFFFF
	MOV BP, SP

	MOV BX, 0x0000
	MOV ES, BX
	MOV BX, 0x80 * 4

	MOV WORD[ES:BX], DOS_INT
	MOV WORD[ES:BX + 2], DS

	MOV DS, AX

	MOV SI, 0x7C00
	MOV AX, DOS_SEGMENT
	MOV ES, AX
	MOV DI, BPB 
	MOV CX, 62
	CALL MEMCPY

	MOV DS, AX

	MOV AH, 0x01
	MOV SI, DOS_STARTUP_MSG
	MOV CX, DOS_STARTUP_MSG_END - DOS_STARTUP_MSG
	INT 0x80

DOS_START:
	MOV AL, 0x00
	MOV DI, DOS_SEGMENT
	MOV ES, DI
	MOV DI, COMMAND
	MOV CX, 128
	CALL MEMSET

	MOV AH, 0x0E
	MOV AL, '>'
	INT 0x10

.AT_LEAST_ONE_CHARACTER:
	MOV AH, 0x02
	MOV SI, COMMAND
	MOV CX, 64
	INT 0x80

	CMP BYTE[COMMAND], 0x00
	JZ .AT_LEAST_ONE_CHARACTER

	MOV AH, 0x0E
	MOV AL, 0x0A
	INT 0x10
	MOV AL, 0x0D
	INT 0x10

	MOV DI, DOS_SEGMENT
	MOV ES, DI
	MOV DI, COMMAND_PARSED

	CLD

PARSE_COMMAND:
	CMP BYTE[SI], ' '
	JNE .STORE

	INC DI

.SPACE_LOOP:
	CMP BYTE[SI], ' '
	JNE .STORE
	INC SI
	DEC CX
	JZ .OUT
	JMP .SPACE_LOOP

.STORE:
	MOV AL, BYTE[SI]
	CALL TO_UPPER
	STOSB
	INC SI
	LOOP PARSE_COMMAND

.OUT:
	MOV SI, COMMAND_LIST
	MOV DI, COMMAND_PARSED
	XOR BX, BX

FIND_COMMAND:
	CALL STRCMP
	JZ COMMAND_FOUND

	CALL STRLEN
	INC CX

	ADD SI, CX
	INC BX

	CMP BYTE[SI], 0xFF
	JNE FIND_COMMAND

	CMP BYTE[COMMAND_PARSED], '\'
	JE LOAD_BINARY

	MOV AH, 0x01
	MOV SI, COMMAND_NOT_FOUND_MSG
	MOV CX, COMMAND_NOT_FOUND_MSG_END - COMMAND_NOT_FOUND_MSG
	INT 0x80

	JMP DOS_START

LOAD_BINARY:
	MOV DI, 0x2000
	MOV ES, DI
	XOR BX, BX
	MOV BX, 0x0000

	MOV AH, 0x04
	MOV SI, COMMAND_PARSED + 1
	MOV CX, 128
	XOR DX, DX
	INT 0x80

	CMP AL, 0x01
	JE NOT_FOUND

	CMP AL, 0x02
	JE READ_ERROR

	MOV DS, DI
	MOV ES, DI

	JMP 0x2000:0x0000

NOT_FOUND:
	MOV AH, 0x01
	MOV SI, FILE_NOT_FOUND_MSG
	MOV CX, FILE_NOT_FOUND_MSG_END - FILE_NOT_FOUND_MSG
	INT 0x80

	JMP DOS_START

READ_ERROR:
	MOV AH, 0x01
	MOV SI, READ_ERROR_MSG
	MOV CX, READ_ERROR_MSG_END - READ_ERROR_MSG
	INT 0x80

	JMP DOS_START

COMMAND_FOUND:
	SHL BX, 1
	ADD BX, COMMAND_ADDRESS_LIST

	MOV AX, WORD[BX]

	JMP AX

; COMMANDS
; --------

; Clears the screen.
; More specificaly sets the screen to 80x25 CGA mode (which is basically clearing the screen).
CLS:
	MOV AX, 0x0003
	INT 0x10
	INT 0x80

; Prints out all files and their sizes (in KiB) in a directory.
DIR:
	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[CURRENT_DIRECTORY]

.PRINT_NAME_LOOP:
	CMP BYTE[ES:BX], 0
	JZ .OUT

	CMP BYTE[ES:BX], 0xE5
	JNE .OK1

	ADD BX, 32
	JMP .PRINT_NAME_LOOP

.OK1:
	CALL NLCR

	CALL PRINT_FILENAME

	MOV AL, ' '
	CALL PUTCHAR

	CALL PRINT_FILE_SIZE

	ADD BX, 32
	MOV CX, 3

.PRINT_MORE:
	CMP BYTE[ES:BX], 0
	JZ .OUT

	CMP BYTE[ES:BX], 0xE5
	JNE .OK2

	ADD BX, 32
	JMP .PRINT_MORE

.OK2:
	MOV AH, 0x0E
	MOV AL, ' '
	INT 0x10
	INT 0x10

	CALL PRINT_FILENAME

	INT 0x10

	CALL PRINT_FILE_SIZE

	ADD BX, 32
	LOOP .PRINT_MORE

	JMP .PRINT_NAME_LOOP

.OUT:
	CALL NLCR

	XOR AH, AH
	INT 0x80

; Does a system reboot.
REBOOT:
	XOR AH, AH
	INT 0x13
	JMP 0xFFFF:0x0000

TEST:
	MOV BX, 0x2000
	MOV ES, BX
	MOV BX, 0xFE00

	MOV AX, 3
	MOV CX, 1
	MOV DX, 0
	CALL READ_DATA

	; MOV AX, 3
	; MOV CX, 4
	; MOV DL, BYTE[DRIVE_NUMBER]
	; CALL READ_DISK
	JC READ_ERROR

	XOR AH, AH
	INT 0x80

; PROCEDURES
; ----------

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

STORE_FAT:
	PUSHA
	PUSH ES

	MOVZX AX, BYTE[NUMBER_OF_FAT]
	MUL WORD[SECTORS_PER_FAT]

	MOV CX, AX

	MOV BX, FILESYSTEM >> 4
	MOV ES, BX
	XOR BX, BX

	MOV AX, WORD[RESERVED_SECTORS]
	MOV DL, BYTE[DRIVE_NUMBER]

	CALL WRITE_DISK

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

	CMP AL, 0x00
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

.LOOP:
	LODSB
	STOSB
	LOOP .LOOP

	POP DI
	POP SI
	POP CX
	POP AX
	RET

; AX <- Current cluster.
; ES:BX <- Source buffer.
; CX <- Number of sectors to write.
; DX <- Sector offset.
WRITE_DATA:
	PUSH AX
	PUSH CX
	PUSH DX
	PUSH DI

	PUSH DX
	SUB AX, 2
	MOVZX DI, BYTE[SECTORS_PER_CLUSTER]
	MUL DI 
	POP DX

	ADD AX, WORD[DATA_AREA_BEGIN]
	ADD AX, DX
	MOV DL, BYTE[DRIVE_NUMBER]
	CALL WRITE_DISK
	JC .OUT

	MOVZX AX, CL
	MUL WORD[BYTES_PER_SECTOR]

	SHR AX, 4

	MOV DI, ES
	ADD DI, AX
	MOV ES, DI

.OUT:
	POP DI
	POP DX
	POP CX
	POP AX
	RET

; AX <- Current cluster.
; ES:BX <- Destination buffer.
; CX <- Number of sectors to read.
; DX <- Sector offset.
READ_DATA:
	PUSH AX
	PUSH CX
	PUSH DX
	PUSH DI

	PUSH DX
	SUB AX, 2
	MOVZX DI, BYTE[SECTORS_PER_CLUSTER]
	MUL DI 
	POP DX

	ADD AX, WORD[DATA_AREA_BEGIN]
	ADD AX, DX
	MOV DL, BYTE[DRIVE_NUMBER]
	CALL READ_DISK
	JC .OUT

	MOVZX AX, CL
	MUL WORD[BYTES_PER_SECTOR]

	SHR AX, 4

	MOV DI, ES
	ADD DI, AX
	MOV ES, DI

.OUT:
	POP DI
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
	OR WORD[ES:BX], DX
	JMP .ODD_CLUSTER

.EVEN_CLUSTER:
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

	XOR AX, AX

	MOV BX, FILESYSTEM >> 4
	MOV ES, BX

.SEARCH:
	MOV BX, AX
	SHR BX, 1
	ADD BX, AX

	PUSH AX
	MOV AX, WORD[ES:BX]
	TEST AX, 1
	JZ .EVEN_CLUSTER	

	SHR AX, 4
	POP AX
	JZ .OUT
	INC AX
	JMP .SEARCH

.EVEN_CLUSTER:
	AND AX, 0x0FFF
	POP AX
	JZ .OUT
	INC AX
	JMP .SEARCH

.OUT:
	POP BX
	POP ES
	RET

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

RESET_DISK:
	PUSH AX

	MOV AH, 0x00
	MOV DL, BYTE[DRIVE_NUMBER]
	INT 0x13

	POP AX
	RET

; FDOS INTERRUPT (INT 0x80)
; -------------------------

DOS_INT:
	PUSHA

	PUSH BX
	PUSH DS

	MOV BX, DOS_SEGMENT
	MOV DS, BX

	MOV BYTE[INT_RET_CODE], 0x00

	MOVZX BX, AH
	SHL BX, 1
	ADD BX, INT_JUMP_TABLE
	MOV DI, WORD[BX]

	POP DS
	POP BX

	JMP DI		

; AH = 0x00
; Returns from the program to 16-DOS.
EXIT_INT:
	POPA

	MOV AX, DOS_SEGMENT
	MOV DS, AX

	XOR AX, AX
	MOV SS, AX
	MOV SP, 0xFFFF

	JMP DOS_SEGMENT:DOS_START

; AH = 0x01
; SI = Pointer to string.
; CX = Number of bytes to print.
PRINT_INT:
	CLD
	MOV AH, 0x0E

.PRINT_LOOP:
	LODSB
	INT 0x10
	LOOP .PRINT_LOOP

	JMP RET_INT

; AH = 0x02
; SI = Pointer to buffer.
; CX = Maximum number of bytes to get from the user.
; Scan terminates when the enter key is pressed.
SCAN_INT:
	MOV DX, SI	

.SCAN_LOOP:
	MOV AH, 0x00
	INT 0x16

	CMP AL, 0x0D
	JE RET_INT

	MOV AH, 0x0E

	CMP AL, 0x08
	JE .BACKSPACE_PRESSED

	TEST CX, CX
	JZ .SCAN_LOOP

	INT 0x10

	MOV BYTE[SI], AL
	INC SI
	LOOP .SCAN_LOOP

.BACKSPACE_PRESSED:
	CMP SI, DX
	JE .SCAN_LOOP

	MOV AL, 0x08
	INT 0x10

	MOV AL, ' '
	INT 0x10

	MOV AL, 0x08
	INT 0x10

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

; AH = 0x04
; ES:BX = Destination buffer.
; SI = Pointer to filename.
; CX = Number of sectors to read.
; DX = Starting sector.
READFILE_INT:
	PUSH DS
	PUSH ES
	PUSH BX

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
	MOV BX, WORD[CURRENT_DIRECTORY]
	CALL FIND_ENTRY
	MOV AX, WORD[ES:BX + 26]

.LABEL_HACK:
	POP BX
	POP ES
	JC .NOT_FOUND

	CALL RESET_DISK

	PUSH ES

	MOV SI, DOS_SEGMENT
	MOV DS, SI

	MOVZX DI, BYTE[SECTORS_PER_CLUSTER]

.GET_TO_STARTING_CLUSTER:
	CMP AX, 0xFF8
	JGE .OUT

	CMP DX, DI
	JL .READ_LOOP

	CALL GET_NEXT_CLUSTER

	SUB DX, DI
	JMP .GET_TO_STARTING_CLUSTER

.READ_LOOP:
	CMP CX, 1
	JL .OUT

	PUSH CX

	CMP CX, DI
	JL .SKIP

	MOV CX, DI
	SUB CX, DX

.SKIP:
	CALL READ_DATA
	POP CX
	JC .READ_ERROR

	CALL GET_NEXT_CLUSTER

	SUB CX, DI
	SUB CX, DX
	XOR DX, DX

	CMP AX, 0xFF8
	JL .READ_LOOP

.OUT:
	POP ES
	POP DS
	JMP RET_CODE_INT

.NOT_FOUND:
	MOV BYTE[INT_RET_CODE], 0x01
	POP DS
	JMP RET_CODE_INT

.READ_ERROR:
	MOV BYTE[INT_RET_CODE], 0x02
	POP ES
	POP DS
	JMP RET_CODE_INT

; TODO: 
; - Upoštevej izjemo za prazen file.
; - Posodobi podatke na disku z novimi podatki v RAM-u.

; AH = 0x05
; ES:BX = Buffer to write.
; SI = Pointer to file entry.
; CX = Number of sectors to write.
; DX = Starting sector.
WRITEFILE_INT:
	PUSH DS
	PUSH ES
	PUSH BX

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
	MOV BX, WORD[CURRENT_DIRECTORY]
	CALL FIND_ENTRY
	MOV AX, WORD[ES:BX + 26]

	MOV WORD[INT_TEMP], BX

.LABEL_HACK:
	POP BX
	POP ES
	JC .NOT_FOUND

	CALL RESET_DISK

	PUSH ES

	MOV SI, DOS_SEGMENT
	MOV DS, SI

	MOV SI, DX

	MOV WORD[INT_WRITE_LAST], AX
	MOVZX DI, BYTE[SECTORS_PER_CLUSTER]

.GET_TO_STARTING_CLUSTER:
	CMP DX, DI
	JL .WRITE_LOOP

	CMP AX, 0xFF8
	JGE .WRITE_ERROR

	MOV WORD[INT_WRITE_LAST], AX
	CALL GET_NEXT_CLUSTER

	SUB DX, DI
	JMP .GET_TO_STARTING_CLUSTER

.WRITE_LOOP:
	CMP CX, 1
	JL .OUT

	CMP AX, 0xFF8
	JL .OK

	PUSH DX
	CALL GET_FREE_CLUSTER
	
	MOV DX, AX
	MOV AX, WORD[INT_WRITE_LAST]
	CALL WRITE_CLUSTER

	CALL GET_NEXT_CLUSTER
	POP DX

.OK:
	PUSH CX
	CMP CX, DI
	JL .SKIP

	MOV CX, DI
	SUB CX, DX

.SKIP:
	CALL WRITE_DATA
	POP CX
	JC .WRITE_ERROR

	MOV WORD[INT_WRITE_LAST], AX
	CALL GET_NEXT_CLUSTER

	SUB CX, DX
	SUB CX, DI
	XOR DX, DX
	JMP .WRITE_LOOP

.OUT:
	POP ES
	POP DS
	JMP RET_CODE_INT

.NOT_FOUND:
	MOV BYTE[INT_RET_CODE], 0x01
	POP DS
	JMP RET_CODE_INT

.WRITE_ERROR:
	MOV BYTE[INT_RET_CODE], 0x02
	POP ES
	POP DS
	JMP RET_CODE_INT

INT_WRITE_LAST: DW 0

RET_CODE_INT:
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
	POPA
	IRET

INT_RET_CODE: DB 0
INT_TEMP: DW 0

INT_JUMP_TABLE:
EXIT_INT_ADDRESS: DW EXIT_INT
PRINT_INT_ADDRESS: DW PRINT_INT
SCAN_INT_ADDRESS: DW SCAN_INT
PRINTI_INT_ADDRESS: DW PRINTI_INT
READFILE_INT_ADDRESS: DW READFILE_INT
WRITEFILE_INT_ADDRESS: DW WRITEFILE_INT
RETURN_FROM_INT_ADDRESS: TIMES 256 - ((RETURN_FROM_INT_ADDRESS - INT_JUMP_TABLE) / 2) DW RET_INT
INT_JUMP_TABLE_END:

COMMAND_LIST:
CLS_COMMAND: DB "CLS", 0x00
DIR_COMMAND: DB "DIR", 0x00
REBOOT_COMMAND: DB "REBOOT", 0x00
TEST_COMMAND: DB "TEST", 0x00
COMMAND_LIST_END: DB 0xFF

COMMAND_ADDRESS_LIST:
CLS_ADDRESS: DW CLS
DIR_ADDRESS: DW DIR
REBOOT_ADDRESS: DW REBOOT
TEST_ADDRESS: DW TEST
COMMAND_ADDRESS_LIST_END:

DOS_STARTUP_MSG: DB "This is FDOS version I.", 0x0A, 0x0D
DOS_STARTUP_MSG_END:

COMMAND_NOT_FOUND_MSG: DB "Command not found.", 0x0A, 0x0D
COMMAND_NOT_FOUND_MSG_END:

FILE_NOT_FOUND_MSG: DB "File not found.", 0x0A, 0x0D
FILE_NOT_FOUND_MSG_END:

READ_ERROR_MSG: DB "Failed to read file.", 0x0A, 0x0D
READ_ERROR_MSG_END:

COMMAND: TIMES 64 DB 0
COMMAND_PARSED: TIMES 64 DB 0

CONVERTED_8_3: TIMES 11 DB ' '

; CURRENT_DIRECTORY_FIRST_SECTOR: DW 0
CURRENT_DIRECTORY: DW 0
DATA_AREA_BEGIN: DW 0

BPB:
SHORT_JUMP:
JMP SHORT BOOT_CODE
NOP
OEM: DB "FDOS    "
BYTES_PER_SECTOR: DW 0
SECTORS_PER_CLUSTER: DB 0
RESERVED_SECTORS: DW 0
NUMBER_OF_FAT: DB 0
ROOT_ENTRIES: DW 0
SECTOR_COUNT: DW 0
MEDIA_DESCRIPTOR: DB 0
SECTORS_PER_FAT: DW 0
SECTORS_PER_TRACK: DW 0
HEAD_COUNT: DW 0
HIDDEN_SECTORS: DD 0
LARGE_SECTOR_COUNT: DD 0

EBR:
DRIVE_NUMBER: DB 0
RESERVED: DB 0
SIGNATURE: DB 0x0
VOLUME_ID: DD 0xFFDD0055
VOLUME_LABEL: DB "FDOS       "
IDENTIFIER_STRING: DB "FAT12   "
BOOT_CODE:
