[CPU 8086]
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
	XOR AX, AX
	MOV DS, AX
	MOV ES, AX

	INT 0x18
