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
	MOV AX, 1000
	MOV BX, 3
	CALL DIV

	PUSH DX

	MOV DX, AX
	MOV AH, 0x03
	INT 0x20

	MOV AH, 0x0E
	MOV BX, 7
	MOV AL, ' '
	INT 0x10

	MOV AH, 0x03
	POP DX
	INT 0x20

	MOV AH, 0x0E
	MOV AL, 0x0D
	INT 0x10
	MOV AH, 0x0E
	MOV AL, 0x0A
	INT 0x10

	XOR AH, AH
	INT 0x20

; AX <- Divident
; BX <- Divizor
; DX <- Ostanek
DIV:
	PUSH BX
	PUSH CX

	XOR CX, CX

.KO_VECJI:
	CMP BX, AX
	JA .ODSTEVAJ

	ADD BX, BX
	JMP .KO_VECJI

.ODSTEVAJ:
	CMP BX, AX
	JA .ZAMAKNI

	SUB AX, BX

	INC CX

.ZAMAKNI:
	SHR BX, 1
	JC .KONEC

	SHL CX, 1
	JMP .ODSTEVAJ

.KONEC:
	MOV DX, AX
	MOV AX, CX

	POP CX
	POP BX
	RET
