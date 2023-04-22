[BITS 16]
[ORG 0x0000]
%INCLUDE "src/locations.h"

	XOR AX, AX
	MOV SS, AX
	MOV SP, 0xFFFF
	MOV BP, SP

	MOV BX, 0x0000
	MOV ES, BX
	MOV BX, 0x80 * 4

	MOV WORD[ES:BX], DOS_INT
	MOV WORD[ES:BX + 2], DS

	MOV SI, 0x7C00
	MOV AX, DOS_SEGMENT
	MOV FS, AX
	MOV DI, BPB 
	MOV CX, 62
	CALL MEMFCPY

	MOV AH, 0x01
	MOV SI, DOS_STARTUP_MSG
	MOV CX, DOS_STARTUP_MSG_END - DOS_STARTUP_MSG - 1 
	INT 0x80

DOS_START:
	MOV AH, 0x0E
	MOV AL, '>'
	INT 0x10

	MOV AH, 0x02
	MOV DI, COMMAND
	MOV CX, 64
	INT 0x80

	MOV AH, 0x0E
	MOV AL, 0x0A
	INT 0x10
	MOV AL, 0x0D
	INT 0x10

	JMP DOS_START

STOP:
	HLT
	JMP STOP

; COMMANDS
; --------

; PROCEDURES
; ----------

; ES:BX <- File name in directory entry.
; SI <- File name to compare to.
;
; ZF -> Set if equal.
FILENAMECMP:
	PUSH AX
	PUSH CX
	PUSH BX
	PUSH SI

	MOV CX, 11

.LOOP:
	LODSB
	CMP AL, BYTE[ES:BX]

	JNE .OUT

	INC BX
	LOOP .LOOP

.OUT:
	POP SI
	POP BX
	POP CX
	POP AX
	RET

; ES:SI <- Source buffer.
; FS:DI <- Destination buffer.
; CX <- Number of bytes to copy.
MEMFCPY:
	PUSH AX
	PUSH CX
	PUSH SI
	PUSH DI

.LOOP:
	MOV AL, BYTE[ES:SI]
	MOV BYTE[FS:DI], AL
	INC SI
	INC DI
	LOOP .LOOP

	POP DI
	POP SI
	POP CX
	POP AX
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
; CL <- Number of sectors to read.
; DL <- Drive number.
; ES:BX <- Pointer to buffer.
WRITE_DISK:
	PUSHA
	PUSH CX
	CALL LBA_TO_CHS
	POP AX 

	MOV AH, 0x03
	MOV DI, 3 

.WRITE_LOOP:
	STC
	PUSH AX
	INT 0x13
	POP AX
	JNC .RETURN

	DEC DI
	JNZ SHORT .WRITE_LOOP

	STC

.RETURN:
	POPA
	RET

; AX <- LBA value.
; CL <- Number of sectors to read.
; DL <- Drive number.
; ES:BX <- Pointer to buffer.
READ_DISK:
	PUSHA
	PUSH CX
	CALL LBA_TO_CHS
	POP AX 

	MOV AH, 0x02
	MOV DI, 3 

.READ_LOOP:
	STC
	PUSH AX
	INT 0x13
	POP AX
	JNC .RETURN

	DEC DI
	JNZ SHORT .READ_LOOP

	STC

.RETURN:
	POPA
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

; FDOS INTERRUPT (INT 0x80)
; -------------------------

DOS_INT:
	PUSHA

	PUSH BX
	PUSH DS

	MOV BX, DOS_SEGMENT
	MOV DS, BX

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

INT_JUMP_TABLE:
EXIT_INT_ADDRESS: DW EXIT_INT
PRINT_INT_ADDRESS: DW PRINT_INT
SCAN_INT_ADDRESS: DW SCAN_INT
RETURN_FROM_INT_ADDRESS: TIMES 256 - ((RETURN_FROM_INT_ADDRESS - INT_JUMP_TABLE) / 2) DW RET_INT
INT_JUMP_TABLE_END:

DOS_STARTUP_MSG: DB "This is FDOS version I.", 0x0A, 0x0D, 0x00
DOS_STARTUP_MSG_END:

COMMAND: TIMES 65 DB 0

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
VOLUME_ID: DD 0x16DD0055
VOLUME_LABEL: DB "16-DOS     "
IDENTIFIER_STRING: DB "FAT12   "
BOOT_CODE:
