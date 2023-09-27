[BITS 16]
[ORG 0x0000]

	MOV AH, 0x13
	MOV SI, FILE
	INT 0x80

	MOV AH, 0
	INT 0x80

FILE: DB "/games/snake.bin", 0

DATA: DB "abcdefghijklmno"
DATA_END:
TIMES 1300 - ($ - $$) DB 'R'
