[BITS 16]
[ORG 0x0000]

	MOV AH, 0x05
	MOV BX, BUFFER
	MOV BX, 0
	MOV SI, FILENAME
	MOV CX, 0xFFFF
	MOV DX, 256
	MOV DI, 0
	INT 0x80

	MOV AH, 0x00
	INT 0x80

FILENAME: DB "ABC.BIN", 0x00
BUFFER:
	MOV AH, 0x0E
	MOV AL, 'A'
	INT 0x10

	MOV AH, 0x00
	INT 0x80

	TIMES 1024 - ($ - $$) DB 'G'
BUFFER_END:
