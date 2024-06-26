CPU 8086
[BITS 16]
[ORG 0x0000]

JMP SHORT START
VERSION: DB 0
SIGNATURE: DW 0xFD05
DB 0xAA
TARGET_SEGMENT: DW 0x0C80
STACK_SEGMENT: DW 0x0C00
STACK_POINTER: DW 0x0800

START:
	MOV AH, 0x16
	MOV SI, SOURCE
	MOV DI, DESTINATION
	INT 0x20

	MOV AH, 0x21
	MOV DH, AL
	INT 0x20

EXIT:
	MOV AH, 0x00
	INT 0x20

SOURCE: DB "/GAMES/TETRIS.PRG", 0x00
DESTINATION: DB "/demo/", 0x00
