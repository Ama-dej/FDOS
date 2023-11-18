[BITS 16]
[ORG 0x0000]

	MOV AH, 0x30
	INT 0x80

	MOV AX, 0xB800
	MOV ES, AX
	XOR BX, BX

	XOR BX, BX
	XOR CX, CX

ZANKA:
	MOV AH, 0x31
	MOV DL, BL
	AND DL, 0x03
	INT 0x80

	INC BX
	INC CX

	CMP BX, 200
	JNE ZANKA

	XOR AH, AH
	INT 0x16

	MOV AH, 0x00
	MOV AL, 0x03
	INT 0x10

	XOR AH, AH
	INT 0x80
