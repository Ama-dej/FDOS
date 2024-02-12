CPU 8086
[BITS 16]
[ORG 0x0000]

%DEFINE FRACTION_PLACES 5
%DEFINE MAX_ITER 30

JMP SHORT PROG_START
VERSION: DB 0
SIGNATURE: DW 0xFD05
DB 0xAA
TARGET_SEGMENT: DW 0x1100
STACK_SEGMENT: DW 0x1000
STACK_POINTER: DW 0x1000

PROG_START:
	INT 0x11
	AND AX, 0x0030
	CMP AX, 0x0030
	JE CGA_REQUIRED

	MOV AH, 0x31
	INT 0x20

	XOR SI, SI
	XOR DI, DI

	; MOV CX, 256 * 128
	MOV CX, 320 * 200

	; Center = (128, 64)

MANDELBROT_LOOP:
	; Fixed point number where the lowest 11 bits represent fractions.

	MOV AX, SI
	SUB AX, 128 + 64 + 4
	SHR AX, 1
	MOV WORD[X_SCALED], AX

	; Same here.
	MOV AX, DI
	SUB AX, 64 + 32
	SHR AX, 1
	MOV WORD[Y_SCALED], AX

	XOR AX, AX
	XOR BX, BX

	PUSH CX
	PUSH SI
	PUSH DI
	MOV CX, MAX_ITER

SEQUENCE:
	MOV DL, AL
	MOV DH, BL

	SUB AL, BL
	ADD BL, DL
	IMUL BL
	; SAR AX, FRACTION_PLACES
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	ADD AX, WORD[X_SCALED]

	PUSH AX

	MOV AL, DL
	MOV BL, DH
	IMUL BL
	; SAR AX, FRACTION_PLACES - 1
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	ADD AX, WORD[Y_SCALED]
	MOV BX, AX

	POP AX
	PUSH AX
	PUSH BX

	IMUL AL
	; SAR AX, FRACTION_PLACES
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	AND AX, 0xFFFF >> FRACTION_PLACES
	MOV DX, AX
	MOV AX, BX
	IMUL AL
	; SAR AX, FRACTION_PLACES
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	SAR AX, 1
	AND AX, 0xFFFF >> FRACTION_PLACES
	ADD AX, DX

	CMP AX, 4 << FRACTION_PLACES
	POP BX
	POP AX
	JA UNSTABLE

	LOOP SEQUENCE	

UNSTABLE:
	POP DI
	POP SI

	TEST CX, CX
	JZ .BLACK

	CMP CX, MAX_ITER / 4 * 3
	JB .CYAN

	CMP CX, MAX_ITER / 6 * 5
	JB .MAGENTA

	MOV DL, 3
	JMP .PUTPIXEL

.BLACK:
	MOV DL, 0
	JMP .PUTPIXEL

.CYAN:
	MOV DL, 1
	JMP .PUTPIXEL

.MAGENTA:
	MOV DL, 2

.PUTPIXEL:
	MOV AH, 0x32
	MOV BX, SI
	MOV CX, DI
	INT 0x20

	POP CX

	INC SI
	CMP SI, 320
	JB CONTINUE

	XOR SI, SI
	INC DI

CONTINUE:
	DEC CX
	JNZ MANDELBROT_LOOP

EXIT:
	XOR AH, AH
	INT 0x16

	MOV AH, 0x30
	INT 0x20

	XOR AH, AH
	INT 0x20

CGA_REQUIRED:
	MOV AH, 0x01
	MOV SI, CGA_REQUIRED_MSG
	MOV CX, CGA_REQUIRED_MSG_END - CGA_REQUIRED_MSG
	INT 0x20

	XOR AH, AH
	INT 0x20

X_SCALED: DW 0
Y_SCALED: DW 0

CGA_REQUIRED_MSG: DB "A CGA compatible card is required for this program.", 0x0A, 0x0D, 0x0A, 0x0D
CGA_REQUIRED_MSG_END:
