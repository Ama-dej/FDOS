CPU 8086
[BITS 16]
[ORG 0x0000]
%INCLUDE "src/locations.h"

	CLI

	MOV WORD[WORKING_DIRECTORY], DX
	MOV DX, DI
	MOV WORD[DATA_AREA_BEGIN], DX

	XOR AX, AX
	MOV SS, AX
	MOV SP, 0x7E00
	MOV BP, SP

	MOV BX, 0x0000
	MOV ES, BX
	MOV BX, 0x20 * 4

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

	MOV AX, WORD[ROOT_ENTRIES]
	MOV WORD[DIRECTORY_SIZE], AX

	XOR DX, DX
	MOV AL, BYTE[SECTORS_PER_CLUSTER]
	XOR AH, AH
	MUL WORD[BYTES_PER_SECTOR]
	MOV WORD[BYTES_PER_CLUSTER], AX

	CALL LOG2
	MOV BYTE[LOG2_CLUSTER_SIZE], CL

	MOV AX, WORD[ROOT_ENTRIES]
	MOV WORD[DIRECTORY_SIZE], AX

	MOV DL, BYTE[DRIVE_NUMBER]
	MOV BYTE[BOOT_DRIVE], DL

	STI

	MOV AH, 0x0F
	INT 0x10
	MOV BYTE[BOOT_VIDEO_MODE], AL

	MOV AH, 0x01
	MOV SI, DOS_STARTUP_MSG
	MOV CX, DOS_STARTUP_MSG_END - DOS_STARTUP_MSG
	INT 0x20

	MOV AH, 0x04
	MOV DX, DOS_SEGMENT << 4 + DOS_OFFSET
	INT 0x20

	CALL NLCR

	MOV AH, 0x01
	MOV SI, MEMORY_MSG
	MOV CX, MEMORY_MSG_END - MEMORY_MSG
	INT 0x20

	INT 0x12
	MOV DX, AX
	MOV AH, 0x03
	INT 0x20

	MOV AH, 0x01
	MOV SI, KIB_SUFFIX
	MOV CX, 4
	INT 0x20

	CALL NLCR

DOS_START:
	MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
	MOV WORD[DIRECTORY_RET_FIRST_SECTOR], AX

	MOV AX, WORD[DIRECTORY_SIZE]
	MOV WORD[DIRECTORY_RET_SIZE], AX

	MOV AL, BYTE[DRIVE_NUMBER]
	MOV BYTE[DRIVE_RET_NUMBER], AL

	MOV AL, 0x00
	MOV DI, DOS_SEGMENT
	MOV ES, DI
	MOV DI, COMMAND
	MOV CX, 128
	CALL MEMSET

	MOV AH, 0x0E
	MOV DL, BYTE[DRIVE_NUMBER]
	CALL DRIVE_TO_LETTER
	INT 0x10

	MOV AH, 0x0E
	MOV AL, ':'
	INT 0x10

	MOV AH, 0x01
	MOV SI, DIRECTORY_PATH
	MOV CX, WORD[PATH_LENGTH]
	INT 0x20

	MOV AH, 0x0E
	MOV AL, '>'
	INT 0x10

.AT_LEAST_ONE_CHARACTER:
	MOV AH, 0x02
	MOV SI, COMMAND
	MOV CX, 79
	INT 0x20

	CMP BYTE[COMMAND], 0x00
	JZ .AT_LEAST_ONE_CHARACTER

	CALL NLCR

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

	CMP BYTE[COMMAND_PARSED], '!'
	JE LOAD_BINARY

	MOV AH, 0x21
	MOV DL, 10
	INT 0x20

	JMP DOS_START

LOAD_BINARY:
	MOV WORD[.FILE_REQUESTED_SEGMENT], 0x1100
	MOV WORD[.STACK_SEGMENT], 0x1000
	MOV WORD[.STACK_POINTER], 0x1000

	MOV SI, DIRECTORY_PATH
	MOV DI, PATH_INFO_BUFFER
	MOV CX, DIRECTORY_INFO_END - DIRECTORY_PATH
	CALL MEMCPY

	MOV AX, WORD[DIRECTORY_SIZE]
	MOV WORD[DIRECTORY_RET_SIZE], AX

	MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
	MOV WORD[DIRECTORY_RET_FIRST_SECTOR], AX

	MOV BX, DOS_SEGMENT
	MOV ES, BX
	MOV BX, DATA_BUFFER
	MOV SI, COMMAND_PARSED + 1	
	; MOV DL, BYTE[DRIVE_NUMBER]
	CALL TRAVERSE_PATH
	JNC NOT_FOUND

	MOV CX, AX
	; SHR CX, 12
	ROL CX, 1
	ROL CX, 1
	ROL CX, 1
	ROL CX, 1
	AND CX, 0x000F

	CMP CL, 1
	JE READ_ERROR

	CMP CL, 4
	JE NOT_FOUND

	AND AX, 0x0FFF
	MOV WORD[WORKING_DIRECTORY_FIRST_SECTOR], AX

	CALL GET_DIRECTORY_SIZE
	MOV WORD[DIRECTORY_SIZE], CX

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]
	MOV DL, BYTE[DRIVE_NUMBER]
	CALL LOAD_DIRECTORY

	MOV BX, FILE_TARGET_SEGMENT
	MOV ES, BX 
	XOR BX, BX

	MOV AH, 0x10
	MOV CX, 8
	XOR DX, DX
	XOR DI, DI
	INT 0x20

	TEST AL, AL
	JNZ .ERROR

	PUSH SI
	CMP BYTE[ES:0x0002], 0
	JA .NON_EXECUTABLE
	; JA .UNRECOGNIZED_VERSION

	CMP WORD[ES:0x0003], 0xFD05
	JNE .NON_EXECUTABLE

	CMP BYTE[ES:0x0005], 0xAA
	JNE .NON_EXECUTABLE

	MOV AX, WORD[ES:0x0006]
	MOV WORD[.FILE_REQUESTED_SEGMENT], AX

	MOV AX, WORD[ES:0x0008]
	MOV WORD[.STACK_SEGMENT], AX
	
	MOV AX, WORD[ES:0x000A]
	MOV WORD[.STACK_POINTER], AX

.EXECUTE_ANYWAYS:
	POP SI
	MOV BX, WORD[.FILE_REQUESTED_SEGMENT]
	MOV ES, BX
	XOR BX, BX

	MOV AH, 0x10
	MOV CX, 0xFFFF
	XOR DX, DX
	XOR DI, DI
	INT 0x20

	TEST AL, AL
	JNZ .ERROR

	MOV AX, DS
	MOV ES, AX

	MOV SI, FIRST_CLUSTERS
	MOV DI, CLUSTERS_BUFFER
	MOV CX, 17
	CALL MEMCPY

	MOV BX, WORD[.STACK_SEGMENT]
	MOV SS, BX
	MOV SP, WORD[.STACK_POINTER]

	MOV BX, WORD[.FILE_REQUESTED_SEGMENT]
	MOV DS, BX
	MOV ES, BX

	DB 0xEA ; >:)
.FAR_JUMP:
	DW 0x0000
.FILE_REQUESTED_SEGMENT: DW 0x0000

.STACK_SEGMENT: DW 0
.STACK_POINTER: DW 0

; .UNRECOGNIZED_VERSION:
	; MOV SI, UNRECOGNIZED_VERSION_MSG
	; MOV CX, UNRECOGNIZED_VERSION_MSG_END - UNRECOGNIZED_VERSION_MSG
	; JMP .PRINT_NON

.NON_EXECUTABLE:
	MOV SI, FILE_NOT_EXECUTABLE_MSG
	MOV CX, FILE_NOT_EXECUTABLE_MSG_END - FILE_NOT_EXECUTABLE_MSG	

.PRINT_NON:
	MOV AH, 0x01
	INT 0x20

	MOV AH, 0x00
	INT 0x16

	MOV AH, 0x0E
	INT 0x10

	CALL TO_UPPER
	CALL NLCR

	CMP AL, 'N'
	JE .RETURN

	CMP AL, 'Y'
	JE .EXECUTE_ANYWAYS

	JMP .PRINT_NON

.ERROR:
	MOV AH, 0x21
	MOV DL, AL
	INT 0x20

.RETURN:
	XOR AH, AH
	INT 0x20

COMMAND_FOUND:
	SHL BX, 1
	ADD BX, COMMAND_ADDRESS_LIST

	MOV AX, WORD[BX]

	JMP AX

; ERRORS
; ------
NOT_FOUND:
	MOV SI, FILE_NOT_FOUND_MSG
	MOV CX, FILE_NOT_FOUND_MSG_END - FILE_NOT_FOUND_MSG - 1
	JMP ERROR_PRINT

DIR_NOT_FOUND:
	MOV SI, DIR_NOT_FOUND_MSG
	MOV CX, DIR_NOT_FOUND_MSG_END - DIR_NOT_FOUND_MSG - 1
	JMP ERROR_PRINT

READ_ERROR:
	MOV SI, READ_ERROR_MSG
	MOV CX, READ_ERROR_MSG_END - READ_ERROR_MSG - 1
	JMP ERROR_PRINT

WRITE_ERROR:
	MOV SI, WRITE_ERROR_MSG
	MOV CX, WRITE_ERROR_MSG_END - WRITE_ERROR_MSG - 1
	JMP ERROR_PRINT

FILE_NOT_DIRECTORY:
	MOV SI, FILE_NOT_DIRECTORY_MSG
	MOV CX, FILE_NOT_DIRECTORY_MSG_END - FILE_NOT_DIRECTORY_MSG - 1
	JMP ERROR_PRINT

INCORRECT_SYNTAX:
	MOV SI, INCORRECT_SYNTAX_MSG
	MOV CX, INCORRECT_SYNTAX_MSG_END - INCORRECT_SYNTAX_MSG - 1
	JMP ERROR_PRINT

FILE_EXISTS:
	MOV SI, FILE_EXISTS_MSG
	MOV CX, FILE_EXISTS_MSG_END - FILE_EXISTS_MSG - 1
	JMP ERROR_PRINT

DIRECTORY_NOT_EMPTY:
	MOV SI, DIRECTORY_NOT_EMPTY_MSG
	MOV CX, DIRECTORY_NOT_EMPTY_MSG_END - DIRECTORY_NOT_EMPTY_MSG - 1
	JMP ERROR_PRINT

ERROR_PRINT:
	MOV AH, 0x01
	INT 0x20

	MOV AL, '.'
	CALL PUTCHAR
	CALL NLCR

	JMP DOS_START

; COMMANDS
; --------

; Boots from a drive with a bootable signature.
BOOT:
	MOV SI, COMMAND_PARSED
	XOR AL, AL
	CALL FINDCHAR
	INC SI

	MOV AL, BYTE[SI]
	CALL LETTER_TO_DRIVE
	JC DOS_START

	XOR AH, AH
	INT 0x13
	JC READ_ERROR

	MOV DI, 3

.LOOP:
	MOV AH, 0x02
	MOV AL, 1
	MOV BX, DOS_SEGMENT
	MOV ES, BX
	MOV BX, DATA_BUFFER
	MOV CX, 1
	XOR DH, DH
	INT 0x13
	JNC .OK

	CMP AH, 0x06
	JNE .RETRY

	CMP DL, BYTE[DRIVE_NUMBER]
	JNE .RETRY

	MOV BYTE[DISKETTE_CHANGED], 1

.RETRY:
	DEC DI
	JNZ .LOOP
	; JMP .OK

.OK:
	CMP WORD[DATA_BUFFER + 510], 0xAA55
	JNE .NOT_BOOTABLE

	MOV SP, 0x7C00
	MOV BP, SP

	MOV SI, DATA_BUFFER
	XOR DI, DI
	MOV ES, DI
	MOV DI, 0x7C00
	MOV CX, 512
	CALL MEMCPY

	JMP 0x0000:0x7C00

.NOT_BOOTABLE:
	MOV AH, 0x01
	MOV SI, NON_BOOTABLE_MSG
	MOV CX, NON_BOOTABLE_MSG_END - NON_BOOTABLE_MSG
	INT 0x20

	JMP DOS_START

NON_BOOTABLE_MSG: DB "Disk does not contain a bootable signature.", 0x0D, 0x0A
NON_BOOTABLE_MSG_END:

; Changes into a subdirectory.
CD:
	MOV AH, 0x12
	MOV SI, COMMAND_PARSED + 3
	INT 0x20

	TEST AL, AL
	JZ .OK

	MOV DL, AL
	MOV AH, 0x21
	INT 0x20
	JMP DOS_START

.OK:
	CALL UPDATE_WORKING_DIRECTORY_PATH
	
	JMP DOS_START

; Clears the screen.
; More specificaly sets the screen to whichever video mode the PC booted with (which is basically clearing the screen).
CLS:
	MOV AH, 0x30
	INT 0x20

	JMP DOS_START

BOOT_VIDEO_MODE: DB 0

; Copies a source file into a destination file.
CP:
	XOR AL, AL
	MOV SI, COMMAND_PARSED
	CALL FINDCHAR
	INC SI

	PUSH SI
	CALL FINDCHAR
	MOV DI, SI
	INC DI
	POP SI

	MOV AH, 0x16
	INT 0x20

	MOV DL, AL
	MOV AH, 0x21
	INT 0x20

	JMP DOS_START

; Prints out all files and their sizes (in KiB) in a directory.
DIR:
	XOR AL, AL
	MOV SI, COMMAND_PARSED
	CALL FINDCHAR
	INC SI

	CMP BYTE[SI], 0
	JE .CURRENT_DIRECTORY

	MOV BX, DOS_SEGMENT
	MOV ES, BX
	MOV BX, DATA_BUFFER
	
	CALL TRAVERSE_PATH
	JNC .IS_ROOT

	; SHR AX, 12
	ROL AX, 1
	ROL AX, 1
	ROL AX, 1
	ROL AX, 1
	AND AX, 0x000F

	MOV AH, 0x21
	MOV DL, AL
	INT 0x20
	JMP DOS_START

.CURRENT_DIRECTORY:
	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]

.IS_ROOT:
	MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]

	TEST AX, AX
	JNZ .NOT_ROOT

	CALL GET_DIRECTORY_SIZE
	; SHL CX, 5
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1
	SHL CX, 1

	PUSH DS
	MOV SI, ES
	MOV DS, SI
	MOV SI, BX
	MOV DI, DOS_SEGMENT
	MOV ES, DI
	MOV DI, DATA_BUFFER
	CALL MEMCPY
	POP DS

	ADD DI, CX
	MOV BYTE[ES:DI], 0 ; prosm?

	MOV BX, DATA_BUFFER
	;  SHR CX, 5
	SHR CX, 1
	SHR CX, 1
	SHR CX, 1
	SHR CX, 1
	SHR CX, 1

.NOT_ROOT:
	; AND AX, 0x0FFF
	MOV SI, BX
	CALL GET_DIRECTORY_SIZE

	CMP CX, 1
	JLE .PRINT_NAME_LOOP

	CALL SORT_ENTRIES

.PRINT_NAME_LOOP:
	CMP BYTE[ES:BX], 0
	JZ .OUT

	CMP BYTE[ES:BX], 0xE5
	JNE .OK

	ADD BX, 32
	JMP .PRINT_NAME_LOOP

.OK:
	MOV AL, ' '
	CALL PUTCHAR
	CALL PUTCHAR

	CALL PRINT_FILENAME

	CALL PUTCHAR
	CALL PUTCHAR

	TEST WORD[ES:BX + 11], 0x10
	JZ .FILE

	MOV DI, CX

	MOV AL, '<'
	CALL PUTCHAR

	MOV AH, 0x01
	MOV SI, DIR_COMMAND
	MOV CX, 3
	INT 0x20

	MOV AL, '>'
	CALL PUTCHAR

	MOV CX, DI
	JMP .CONTINUE

.FILE:
	CALL GET_FILE_SIZE
	CALL PRINT_FILE_SIZE

.CONTINUE:
	ADD BX, 32
	CALL NLCR
	JMP .PRINT_NAME_LOOP

.OUT:
	CALL NLCR
	JMP DOS_START

; Reads the filesystem info from a FAT12 formatted floppy disk in a specific drive.
DSK:
	MOV SI, COMMAND_PARSED
	XOR AL, AL
	CALL FINDCHAR
	INC SI

	MOV AL, BYTE[SI]
	CALL LETTER_TO_DRIVE

	CMP DL, 0x80
	JAE .ILLEGAL_DRIVE

	MOV SI, BPB
	MOV DI, DOS_SEGMENT
	MOV ES, DI
	MOV DI, DATA_BUFFER + 512
	MOV CX, BOOT_CODE - BPB
	CALL MEMCPY

	XOR AH, AH
	INT 0x13
	JC .ERROR

	MOV DI, 3

.LOOP:
	MOV AH, 0x02
	MOV AL, 1
	MOV CX, 1
	XOR DH, DH
	MOV BX, BPB 
	INT 0x13
	JNC .OK

	CMP AH, 0x06
	JNE .RETRY

	CMP DL, BYTE[DRIVE_NUMBER]
	JNE .RETRY

	MOV BYTE[DISKETTE_CHANGED], 1
	CALL READ_DISK

	JMP DOS_START

.RETRY:
	DEC DI
	JNZ .LOOP
	JMP .ERROR

.OK:
	MOV BYTE[DISKETTE_CHANGED], 0

	MOV BX, DATA_BUFFER + 512 + BOOT_CODE - BPB
	CALL LOAD_FAT
	JC .ERROR

	MOV BYTE[DRIVE_NUMBER], DL

	XOR DX, DX
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
	
	MOV SI, BX
	XOR DI, DI
	MOV ES, DI
	MOV DI, FILESYSTEM
	CALL MEMCPY

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

	MOV AH, 0x12
	MOV SI, ROOT_DIRECTORY_PATH
	INT 0x20

	TEST AL, AL
	JNZ .ROOT_ERROR

	CALL UPDATE_WORKING_DIRECTORY_PATH

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]
	CALL GET_DIRECTORY_SIZE

	MOV WORD[DIRECTORY_SIZE], CX

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

	JMP DOS_START

.ROOT_ERROR:
	MOV BYTE[DISKETTE_CHANGED], 1

.ERROR:
	MOV SI, DATA_BUFFER + 512
	MOV DI, BPB
	MOV CX, BOOT_CODE - BPB
	CALL MEMCPY

	MOV AH, 0x21
	MOV DL, 1
	INT 0x20

	JMP DOS_START

.ILLEGAL_DRIVE:
	MOV AH, 0x01
	MOV SI, ILLEGAL_DRIVE_MSG
	MOV CX, ILLEGAL_DRIVE_MSG_END - ILLEGAL_DRIVE_MSG
	INT 0x20

	JMP DOS_START

ILLEGAL_DRIVE_MSG: DB "Illegal drive letter.", 0x0A, 0x0D
ILLEGAL_DRIVE_MSG_END:

; Lists information of drives detected by FDOS.
LSDSK:
	MOV AL, 'A'

.LIST_LOOP:
	CALL LETTER_TO_DRIVE

	MOV SI, DRIVE_ICON

	MOV BX, DOS_SEGMENT
	MOV ES, BX
	MOV BX, DATA_BUFFER
	MOV CX, 1

.READ_LOOP:
	PUSH AX
	MOV AH, 0x02
	MOV AL, 1
	XOR DH, DH
	INT 0x13
	MOV DH, AH
	POP AX
	JNC .PRINT_DRIVE

	CMP DH, 0x06
	JE .DISKETTE_CHANGED

	MOV SI, DRIVE_ICON_EMPTY

	CMP AL, 'B'
	JA .ERROR

	CMP DH, 0x01
	JE .ERROR

.PRINT_DRIVE:
	MOV DH, AL

	CMP DL, BYTE[DRIVE_NUMBER]
	JE .CURRENT_DRIVE

	MOV AL, ' '
	JMP .PRINT1

.CURRENT_DRIVE:
	MOV AL, '>'

.PRINT1:
	MOV AH, 0x0E
	INT 0x10

	CMP DL, BYTE[BOOT_DRIVE]
	JE  .BOOT_DRIVE

	MOV AL, ' '
	JMP .PRINT2

.BOOT_DRIVE:
	MOV AL, '*'

.PRINT2:
	MOV AH, 0x0E
	INT 0x10

	MOV AH, 0x0E
	MOV AL, DH
	INT 0x10

	MOV AH, 0x0E
	MOV AL, ':'
	INT 0x10

	MOV AH, 0x0E
	MOV AL, ' '
	INT 0x10

	CMP DL, 0x80
	JB .PRINT_ICON

	MOV SI, HDD_ICON

.PRINT_ICON:
	MOV AH, 0x01
	MOV CX, 5
	INT 0x20

	CALL NLCR

	MOV AL, DH

.ERROR:
	PUSH AX
	XOR AH, AH
	INT 0x13
	POP AX

	INC AL
	CMP AL, 'Z'
	JBE .LIST_LOOP

	CALL NLCR
	JMP DOS_START

.DISKETTE_CHANGED:
	CMP DL, BYTE[DRIVE_NUMBER]
	JNE .PRINT_DRIVE

	MOV BYTE[DISKETTE_CHANGED], 1
	JMP .PRINT_DRIVE

DRIVE_ICON: DB 0xCD, 0xB8, 0xDC, 0xD5, 0xCD
DRIVE_ICON_EMPTY: DB 0xCD, 0xB8, 0x20, 0xD5, 0xCD
HDD_ICON: DB 0xDC, 0xDC, 0xDC, 0xD2, 0xDC

; Creates a file.
MK:
	XOR AL, AL
	MOV SI, COMMAND_PARSED
	CALL FINDCHAR
	INC SI

	MOV AH, 0x14
	INT 0x20

	MOV AH, 0x21
	MOV DL, AL
	INT 0x20

	JMP DOS_START

; Creates a directory.
MKDIR:
	XOR AL, AL
	MOV SI, COMMAND_PARSED
	CALL FINDCHAR
	INC SI

	MOV AH, 0x15
	INT 0x20

	MOV AH, 0x21
	MOV DL, AL
	INT 0x20

	JMP DOS_START

; Does a system reboot.
REBOOT:
	XOR AH, AH
	INT 0x13
	JMP 0xFFFF:0x0000

; Disablana REN procedura, ker je zanič spisana in me je razjezila (zelo sm popenu).
%if 0
REN:
	XOR AL, AL
	MOV SI, COMMAND_PARSED
	CALL FINDCHAR

	INC SI
	MOV DX, SI

	CALL FINDCHAR
	MOV CX, SI
	INC CX
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
	JC NOT_FOUND

	MOV AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]
	MOV DL, BYTE[DRIVE_NUMBER]

	JMP .OK

.FOUND_IT:
	INC SI
	MOV DI, FILENAME_BUFFER
	CALL CONVERT_TO_8_3
	JC NOT_FOUND

	CMP BYTE[SI], '.'
	JE INCORRECT_SYNTAX

	MOV BYTE[SI], 0

	MOV SI, DX
	MOV BX, DATA_BUFFER
	CALL TRAVERSE_PATH
	JNC .OK

	CALL PATH_ERRORS

.OK:
	MOV WORD[CONVERTED_8_3], BX

	MOV SI, FILENAME_BUFFER

	CMP BYTE[SI], '.'
	JE NOT_FOUND

	CALL FIND_ENTRY
	MOV DI, WORD[ES:BX + 26]
	MOV WORD[COMMAND], DI
	JC NOT_FOUND

	MOV SI, CX
	CMP BYTE[SI], 0
	JZ INCORRECT_SYNTAX

	CMP BYTE[SI], '/'
	JZ INCORRECT_SYNTAX

	CMP BYTE[SI], '.'
	JZ INCORRECT_SYNTAX

	PUSH ES
	MOV DI, DOS_SEGMENT
	MOV ES, DI
	MOV DI, FILENAME_BUFFER
	CALL CONVERT_TO_8_3
	POP ES
	JC INCORRECT_SYNTAX

	PUSH ES
	PUSH BX
	MOV BX, WORD[CONVERTED_8_3]
	MOV SI, FILENAME_BUFFER
	CALL FIND_ENTRY
	POP BX
	POP ES
	JNC FILE_EXISTS

	MOV SI, DI
	; MOV SI, FILENAME_BUFFER
	MOV DI, BX
	MOV CX, 11 
	CALL MEMCPY

	; MOV BYTE[ES:BX], 'R'
	
	MOV BX, WORD[CONVERTED_8_3]
	CALL GET_DIRECTORY_SIZE

	CALL STORE_DIRECTORY
	JC READ_ERROR

	CMP AX, WORD[WORKING_DIRECTORY_FIRST_SECTOR]
	JNE .CHECK_PATH_VALIDITY

	XOR BX, BX
	MOV ES, BX
	MOV BX, WORD[WORKING_DIRECTORY]
	MOV DL, BYTE[DRIVE_NUMBER]
	CALL LOAD_DIRECTORY

.CHECK_PATH_VALIDITY:
	MOV AX, WORD[COMMAND]
	MOV SI, FIRST_CLUSTERS
	CALL IS_PATH_VALID
	JNC .OUT

	MOV SI, DIRECTORY_PATH + 1
	CALL FIND_NEIP

	CALL ENTRY_LEN
	MOV DX, CX

	MOV BX, SI

	XOR AL, AL 
	MOV SI, COMMAND_PARSED
	CALL FINDCHAR

	INC SI
	CALL FINDCHAR

	INC SI
	CALL FINDCHAR

	INC SI
	CALL ENTRY_LEN

	PUSH SI
	PUSH CX

	CMP CX, DX
	JE .COPY

	PUSH CX
	SUB CX, DX
	ADD WORD[PATH_LENGTH], CX
	POP CX

	CMP CX, DX
	JB .LOWER_THAN

	MOV DI, DIRECTORY_PATH + 120
	MOV SI, DI
	SUB CX, DX
	ADD DI, CX
	MOV CX, 160
	MOV DX, BX
	SUB DX, DIRECTORY_PATH
	SUB CX, DX
	STD

	JMP .COPY_LOOP

.GREATER_THAN_LOOP:
	LODSB
	STOSB

	LOOP .GREATER_THAN_LOOP

	JMP .COPY

.LOWER_THAN:
	MOV DI, BX
	ADD DI, CX
	MOV SI, BX
	ADD SI, DX
	MOV DX, DI
	SUB DX, DIRECTORY_PATH
	MOV CX, 120
	SUB CX, DX

	CLD

.COPY_LOOP:
	LODSB
	STOSB

	LOOP .COPY_LOOP

	JMP .COPY

.COPY:
	POP CX
	POP SI
	MOV DI, BX
	CALL MEMCPY

.OUT:
	JMP DOS_START
%endif

FILENAME_BUFFER: TIMES 11 DB 0

; Removes a file or directory.
RM:
	XOR AL, AL
	MOV SI, COMMAND_PARSED
	CALL FINDCHAR

	INC SI
	MOV AH, 0x13
	INT 0x20

	MOV AH, 0x21
	MOV DL, AL
	INT 0x20

	JMP DOS_START

; A command used for testing.
TEST:
	CLI

	XOR AL, AL
	OUT 0x43, AL

	IN AL, 0x40
	MOV DL, AL
	IN AL, 0x40
	MOV AH, AL

	MOV AL, 10
	OUT 0x40, AL
	OUT 0x40, AL

	MOV AL, 0b00110100
	OUT 0x43, AL

	; MOV AL, DL
	MOV AL, 0xFF
	OUT 0x40, AL
	; MOV AL, DH
	OUT 0x40, AL

	STI

	JMP DOS_START

TYPE:
	XOR AL, AL
	MOV SI, COMMAND_PARSED
	CALL FINDCHAR
	INC SI

	MOV AH, 0x10
	MOV BX, 0x1000
	MOV ES, BX
	XOR BX, BX
	MOV CX, 0xFFFF
	XOR DX, DX
	XOR DI, DI
	INT 0x20

	TEST AL, AL
	JZ .OK

	MOV AH, 0x21
	MOV DL, AL
	INT 0x20

	JMP DOS_START

.OK:
	MOV AH, 0x01
	MOV SI, 0x1000
	MOV DS, SI
	XOR SI, SI
	INT 0x20

	CALL NLCR

	MOV AX, DOS_SEGMENT
	MOV DS, AX

	JMP DOS_START

%INCLUDE "src/procedures.asm"
%INCLUDE "src/interrupts.asm"

COMMAND_LIST:
BOOT_COMMAND: DB "BOOT", 0x00
CD_COMMAND: DB "CD", 0x00
CLS_COMMAND: DB "CLS", 0x00
CP_COMMAND: DB "CP", 0x00
DIR_COMMAND: DB "DIR", 0x00
DSK_COMMAND: DB "DSK", 0x00
LSDSK_COMMAND: DB "LSDSK", 0x00
MK_COMMAND: DB "MK", 0x00
MKDIR_COMMAND: DB "MKDIR", 0x00
REBOOT_COMMAND: DB "REBOOT", 0x00
; REN_COMMAND: DB "REN", 0x00
RM_COMMAND: DB "RM", 0x00
TEST_COMMAND: DB "TEST", 0x00
TYPE_COMMAND: DB "TYPE", 0x00
COMMAND_LIST_END: DB 0xFF

COMMAND_ADDRESS_LIST:
BOOT_ADDRESS: DW BOOT
CD_ADDRESS: DW CD
CLS_ADDRESS: DW CLS
CP_ADDRESS: DW CP
DIR_ADDRESS: DW DIR
DSK_ADDRESS: DW DSK
LSDSK_ADDRESS: DW LSDSK
MK_ADDRESS: DW MK
MKDIR_ADDRESS: DW MKDIR
REBOOT_ADDRESS: DW REBOOT
; REN_ADDRESS: DW REN
RM_ADDRESS: DW RM
TEST_ADDRESS: DW TEST
TYPE_ADDRESS: DW TYPE
COMMAND_ADDRESS_LIST_END:

DOS_STARTUP_MSG: DB "FDOS kernel -> 0x0"
DOS_STARTUP_MSG_END:

MEMORY_MSG: DB "Lower RAM -> "
MEMORY_MSG_END:

FILE_NOT_EXECUTABLE_MSG: DB "Program is not marked as executable, still execute it? [y/n]: "
FILE_NOT_EXECUTABLE_MSG_END:

UNRECOGNIZED_VERSION_MSG: DB "Executable is of an unknown version, still execute it? [y/n]: "
UNRECOGNIZED_VERSION_MSG_END:

READ_ERROR_MSG: DB "Failed to read from disk", 0x00
READ_ERROR_MSG_END:
WRITE_ERROR_MSG: DB "Failed to write to disk", 0x00
WRITE_ERROR_MSG_END:
FILE_NOT_FOUND_MSG: DB "File not found", 0x00
FILE_NOT_FOUND_MSG_END:
DIR_NOT_FOUND_MSG: DB "Directory not found", 0x00
DIR_NOT_FOUND_MSG_END:
INCORRECT_SYNTAX_MSG: DB "The syntax is incorrect", 0x00
INCORRECT_SYNTAX_MSG_END:
FILE_EXISTS_MSG: DB "File already exists", 0x00
FILE_EXISTS_MSG_END:
FILE_NOT_DIRECTORY_MSG: DB "The specified file is not a directory", 0x00
FILE_NOT_DIRECTORY_MSG_END:
DIRECTORY_NOT_EMPTY_MSG: DB "The directory must be empty", 0x00
DIRECTORY_NOT_EMPTY_MSG_END:
NO_SPACE_MSG: DB "No space left on disk", 0x00
NO_SPACE_MSG_END:
COMMAND_NOT_FOUND_MSG: DB "Command not found", 0x00
COMMAND_NOT_FOUND_MSG_END:
MAX_DIR_DEPTH_MSG: DB "Maximum directory depth reached", 0x00
MAX_DIR_DEPTH_MSG_END:
FILE_IS_A_DIRECTORY_MSG: DB "The specified file is a directory", 0x00
FILE_IS_A_DIRECTORY_MSG_END:

ERROR_MSG_ADDRESS_START:
READ_ERROR_MSG_ADDRESS: DW READ_ERROR_MSG
WRITE_ERROR_MSG_ADDRESS: DW WRITE_ERROR_MSG
FILE_NOT_FOUND_MSG_ADDRESS: DW FILE_NOT_FOUND_MSG
DIR_NOT_FOUND_MSG_ADDRESS: DW DIR_NOT_FOUND_MSG
INCORRECT_SYNTAX_MSG_ADDRESS: DW INCORRECT_SYNTAX_MSG
FILE_EXISTS_MSG_ADDRESS: DW FILE_EXISTS_MSG
FILE_NOT_DIRECTORY_MSG_ADDRESS: DW FILE_NOT_DIRECTORY_MSG
DIRECTORY_NOT_EMPTY_MSG_ADDRESS: DW DIRECTORY_NOT_EMPTY_MSG
NO_SPACE_MSG_ADDRESS: DW NO_SPACE_MSG
COMMAND_NOT_FOUND_MSG_ADDRESS: DW COMMAND_NOT_FOUND_MSG
MAX_DIR_DEPTH_MSG_ADDRESS: DW MAX_DIR_DEPTH_MSG
FILE_IS_A_DIRECTORY_MSG_ADDRESS: DW FILE_IS_A_DIRECTORY_MSG
ERROR_MSG_ADDRESS_END:

COMMAND: TIMES 79 DB 0
COMMAND_PARSED: TIMES 79 DB 0
DB 0

CONVERTED_8_3: TIMES 11 DB ' '
ROOT_DIRECTORY_PATH: DB '/', 0x00

BOOT_DRIVE: DB 0
DISKETTE_CHANGED: DB 0

WORKING_DIRECTORY: DW 0

WORKING_DIRECTORY_FIRST_SECTOR: DW 0
DIRECTORY_SIZE: DW 0

DIRECTORY_RET_FIRST_SECTOR: DW 0
DIRECTORY_RET_SIZE: DW 0
DRIVE_RET_NUMBER: DB 0

DATA_AREA_BEGIN: DW 0
BYTES_PER_CLUSTER: DW 0
LOG2_CLUSTER_SIZE: DB 0

DIRECTORY_PATH: DB '/'
TIMES 120 DB 0
PATH_LENGTH: DW 1
FIRST_CLUSTERS: TIMES 8 DW 0xFFFF
FIRST_CLUSTERS_LENGTH: DB 0
DIRECTORY_INFO_END:

PATH_INFO_BUFFER: TIMES DIRECTORY_INFO_END - DIRECTORY_PATH DB 0

CLUSTERS_BUFFER: TIMES 17 DB 0
DB 0
TEMP_BUFFER: TIMES 120 DB 0

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

DATA_BUFFER:
