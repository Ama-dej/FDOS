CPU 8086
[BITS 16]
[ORG 0x0000]

%DEFINE PADDLE_LENGTH 3
%DEFINE LEFT_PADDLE_X 1
%DEFINE RIGHT_PADDLE_X 78
%DEFINE DELAY_MS 35

JMP SHORT START
VERSION: DB 0
SIGNATURE: DW 0xFD05
DB 0xAA
TARGET_SEGMENT: DW 0x1100
STACK_SEGMENT: DW 0x1000
STACK_POINTER: DW 0x1000

START:
        MOV AX, 0x1003
        MOV BL, 0x00
        INT 0x10 ; Turn off blinking attribute.

        MOV AH, 0x00
        MOV AL, 0x03
        INT 0x10 ; Set display to 80x25 and 16 bits of colour.

        MOV AH, 0x01
        MOV CX, 0x2607
        INT 0x10 ; Make the cursor invisible.

DRAW_PADDLES:
	MOV AL, ' '
	MOV BL, 0xFF
	MOV DH, BYTE[LEFT_PADDLE_Y]
	MOV DL, LEFT_PADDLE_X

	MOV CX, PADDLE_LENGTH

.LEFT_DRAW_LOOP:
	CALL PUTCHAR_AT_COORDS
	INC DH
	LOOP .LEFT_DRAW_LOOP

	MOV DH, BYTE[RIGHT_PADDLE_Y]
	MOV DL, RIGHT_PADDLE_X

	MOV CX, PADDLE_LENGTH

.RIGHT_DRAW_LOOP:
	CALL PUTCHAR_AT_COORDS
	INC DH
	LOOP .RIGHT_DRAW_LOOP

GAME_LOOP:
	MOV DX, WORD[BALL_COORDINATES]

	TEST BYTE[BALL_DIRECTION], 0x01
	JZ .DEC_X

	CMP DL, RIGHT_PADDLE_X - 2
	JB .CONT_INC_X

	MOV BH, BYTE[RIGHT_PADDLE_Y]

	CMP DH, BH
	JL .LEFT_POINT

	ADD BH, PADDLE_LENGTH - 1

	CMP DH, BH
	JG .LEFT_POINT

	XOR BYTE[BALL_DIRECTION], 0x01
	JMP .CONT_DEC_X

.CONT_INC_X:
	INC BYTE[BALL_X]
	JMP .Y

.DEC_X:
	CMP DL, LEFT_PADDLE_X + 1
	JA .CONT_DEC_X

	MOV BH, BYTE[LEFT_PADDLE_Y]

	CMP DH, BH
	JL .RIGHT_POINT

	ADD BH, PADDLE_LENGTH - 1

	CMP DH, BH
	JG .RIGHT_POINT

	XOR BYTE[BALL_DIRECTION], 0x01
	JMP .CONT_INC_X

.LEFT_POINT:
	INC WORD[LEFT_SCORE]
	JMP .RESET_BALL_COORDS

.RIGHT_POINT:
	INC WORD[RIGHT_SCORE]

.RESET_BALL_COORDS:
	MOV BYTE[BALL_Y], 25 / 2
	MOV BYTE[BALL_X], 40
	JMP .UPDATE_POSITION
	
.CONT_DEC_X:
	DEC BYTE[BALL_X]

.Y:
	TEST BYTE[BALL_DIRECTION], 0x02
	JZ .DEC_Y

	CMP DH, 24
	JNE .CONT_INC_Y

	XOR BYTE[BALL_DIRECTION], 0x02
	JMP .CONT_DEC_Y

.CONT_INC_Y:
	INC BYTE[BALL_Y]
	JMP .UPDATE_POSITION

.DEC_Y:
	TEST DH, DH
	JNZ .CONT_DEC_Y

	XOR BYTE[BALL_DIRECTION], 0x02
	JMP .CONT_INC_Y

.CONT_DEC_Y:
	DEC BYTE[BALL_Y]

.UPDATE_POSITION:
	MOV AL, ' '
	MOV BL, 0x07
	CALL PUTCHAR_AT_COORDS
	
	INC DL
	CALL PUTCHAR_AT_COORDS

	MOV DX, WORD[BALL_COORDINATES]

	MOV AL, ' '
	MOV BL, 0xCC
	CALL PUTCHAR_AT_COORDS
	
	INC DL
	CALL PUTCHAR_AT_COORDS

	MOV AH, 0x02
	MOV BH, 0
	MOV DH, 1 
	MOV DL, 38 
	
	CMP WORD[LEFT_SCORE], 10 ; nočna mora
	JB .PRINT
	DEC DL

	CMP WORD[LEFT_SCORE], 100
	JB .PRINT
	DEC DL

	CMP WORD[LEFT_SCORE], 1000
	JB .PRINT
	DEC DL

	CMP WORD[LEFT_SCORE], 10000 ; ne maram tega kar sm tle naredu
	JB .PRINT
	DEC DL

.PRINT:
	INT 0x10

	MOV DX, WORD[LEFT_SCORE]
	MOV AH, 0x03
	INT 0x20 ; učinkovitost

	MOV AH, 0x02
	MOV BH, 0
	MOV DH, 1 
	MOV DL, 41
	INT 0x10

	MOV DX, WORD[RIGHT_SCORE]
	MOV AH, 0x03
	INT 0x20

GET_KEY:
	MOV AH, 0x01
        INT 0x16 ; Check if a key is pressed.
	JZ DELAY

	CMP BYTE[KEYS_REMAINING], 0
	JZ DELAY

	DEC BYTE[KEYS_REMAINING]

        MOV AH, 0x00
        INT 0x16 ; Get the key.

        CMP AH, 0x48 ; Up arrow.
        JE RIGHT_UP_PRESSED

        CMP AH, 0x50 ; Down arrow.
        JE RIGHT_DOWN_PRESSED

        CMP AL, 0
        JE DELAY

        CMP AX, 0x011B
        JE EXIT

        OR AL, 0b00100000 ; Convert to lowercase (so it works even if caps lock is on).

        CMP AL, 'w'
        JE LEFT_UP_PRESSED

        CMP AL, 's'
        JE LEFT_DOWN_PRESSED

        ; CMP AL, 'p'
        ; JE P_PRESSED

        JMP DELAY

LEFT_UP_PRESSED:
	CMP BYTE[LEFT_PADDLE_Y], 0
	JZ GET_KEY

	DEC BYTE[LEFT_PADDLE_Y]

	MOV DH, BYTE[LEFT_PADDLE_Y]
	MOV DL, LEFT_PADDLE_X
	MOV BL, 0xF0
	JMP MOVE_PADDLE

RIGHT_UP_PRESSED:
	CMP BYTE[RIGHT_PADDLE_Y], 0
	JZ GET_KEY

	DEC BYTE[RIGHT_PADDLE_Y]

	MOV DH, BYTE[RIGHT_PADDLE_Y]
	MOV DL, RIGHT_PADDLE_X
	MOV BL, 0xF0
	JMP MOVE_PADDLE

LEFT_DOWN_PRESSED:
	CMP BYTE[LEFT_PADDLE_Y], 22
	JZ GET_KEY

	MOV DH, BYTE[LEFT_PADDLE_Y]
	MOV DL, LEFT_PADDLE_X

	INC BYTE[LEFT_PADDLE_Y]
	MOV BL, 0x0F
	JMP MOVE_PADDLE

RIGHT_DOWN_PRESSED:
	CMP BYTE[RIGHT_PADDLE_Y], 22
	JZ GET_KEY

	MOV DH, BYTE[RIGHT_PADDLE_Y]
	MOV DL, RIGHT_PADDLE_X

	INC BYTE[RIGHT_PADDLE_Y]

	MOV BL, 0x0F
	JMP MOVE_PADDLE

MOVE_PADDLE:
	MOV AL, ' '
	CALL PUTCHAR_AT_COORDS

	NOT BL

	ADD DH, PADDLE_LENGTH
	CALL PUTCHAR_AT_COORDS

	JMP GET_KEY

DELAY:
	MOV CX, DELAY_MS

.WAIT_LOOP:
	PUSH CX
        MOV AH, 0x86
        XOR CX, CX
        MOV DX, 0x03E8
        INT 0x15 ; Wait for 1ms.
	POP CX

	LOOP .WAIT_LOOP

	MOV BYTE[KEYS_REMAINING], 30 
	JMP GAME_LOOP

EXIT:
	MOV AH, 0x30
	INT 0x20

	XOR AH, AH
	INT 0x20

; AL -> ASCII character to write.
; BL -> Character attribute (text), foreground colour (graphics).
; DH -> Y coordinate.
; DL -> X coordinate.
PUTCHAR_AT_COORDS:
	PUSH AX
	PUSH BX
	PUSH CX

	MOV AH, 0x02
	XOR BH, BH
	INT 0x10

	MOV AH, 0x09
	MOV CX, 1
	INT 0x10

	POP CX
	POP BX
	POP AX
	RET

LEFT_PADDLE_Y: DB 25 / 2 - PADDLE_LENGTH / 2
RIGHT_PADDLE_Y: DB 25 / 2 - PADDLE_LENGTH / 2

; 00 -> y--, x--
; 01 -> y--, x++
; 10 -> y++, x--
; 11 -> y++, x++
BALL_DIRECTION: DB 0
BALL_COORDINATES:
BALL_X: DB 40
BALL_Y: DB 25 / 2

KEYS_REMAINING: DB 30

LEFT_SCORE: DW 0
RIGHT_SCORE: DW 0
