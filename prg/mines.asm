[BITS 16]
[ORG 0x0000]

%DEFINE SELECTED_ATTRIBUTE 0xE0

JMP SHORT START
VERSION: DB 0
SIGNATURE: DW 0xFD05
DB 0xAA
TARGET_SEGMENT: DW 0x1100
STACK_SEGMENT: DW 0x1000
STACK_POINTER: DW 0x1000

START:
	MOV AX, 0x0003
	INT 0x10

	XOR AL, AL
	MOV BX, ASCII_NUM
	MOV CX, 3
	CALL MEMSET

	MOV AH, 0x01
	MOV SI, MINE_COUNT_MSG
	MOV CX, MINE_COUNT_MSG_END - MINE_COUNT_MSG
	INT 0x80

	MOV AH, 0x02
	MOV SI, ASCII_NUM
	MOV CX, 3
	INT 0x80

	XOR AX, AX

TO_INT:
	MOV CL, BYTE[SI]

	TEST CL, CL
	JZ .EXIT

	CMP CL, '0'
	JB START

	CMP CL, '9'
	JA START

	XOR DX, DX
	MOV BX, 10
	MUL BX

	XOR CH, CH
	SUB CL, '0'
	ADD AX, CX

.CONTINUE:
	INC SI
	JMP TO_INT

.EXIT:
	MOV WORD[MINE_COUNT], AX
	MOV DX, 1000
	SUB DX, AX
	MOV WORD[SAFE_TILE_COUNT], DX

	MOV CX, AX
	MOV AL, 0x30
	MOV BX, FIELD
	CALL MEMSET

	MOV AX, 0x0001
	INT 0x10 ; Set to 40x25 with 16 colours.

	MOV AH, 0x01
        MOV CX, 0x2607
        INT 0x10 ; Make the cursor invisible.

	MOV AX, 0x1003
        MOV BL, 0x00
        INT 0x10 ; Turn off blinking attribute.

	MOV AH, 0x00
        INT 0x1A ; Get the number of clock ticks since midnight.

	ADD DX, CX
	MOV WORD[SEED], DX

	XOR AL, AL
	MOV BX, FIELD
	ADD BX, WORD[MINE_COUNT]
	MOV CX, 40 * 25
	SUB CX, WORD[MINE_COUNT]
	CALL MEMSET

	MOV CX, WORD[MINE_COUNT]
	MOV BX, 1000
	MOV SI, FIELD

LOOP:
	CALL GET_RANDOM_NUMBER

	XOR DX, DX
	DIV BX 

	MOV DI, FIELD
	ADD DI, DX

	MOV AL, BYTE[SI]
	MOV AH, BYTE[DI]
	MOV BYTE[SI], AH
	MOV BYTE[DI], AL
	INC SI

	LOOP LOOP

	MOV CX, 40 * 25
	MOV SI, FIELD

COUNT_SURROUNDING:
	PUSH CX

	CMP BYTE[SI], 0x30
	JE .SKIP

	MOV CH, -1
	MOV AL, 0x10

.Y_LOOP:
	MOV CL, -1

.X_LOOP:
	CALL SURROUNDING_IN_FIELD
	JC .X_SKIP

	CALL SURROUNDING_IS_MINE
	JNE .X_SKIP

	INC AL

.X_SKIP:
	INC CL
	CMP CL, 1
	JLE .X_LOOP

	INC CH
	CMP CH, 1
	JLE .Y_LOOP

	MOV BYTE[SI], AL

.SKIP:
	INC SI
	POP CX
	LOOP COUNT_SURROUNDING

	MOV SI, FIELD
	MOV AL, ' '
	XOR BH, BH
	MOV CX, 1
	XOR DH, DH
	
	CLD

PRINT_FIELD:
	XOR DL, DL

.X_LOOP:
	MOV BL, 0x70

	PUSH DX
	ADD DL, DH
	TEST DL, 1
	POP DX
	JZ .LIGHT
	
	MOV BL, 0x80
	
.LIGHT:
	MOV AH, 0x09
	INT 0x10

	INC DL

	MOV AH, 0x02
	INT 0x10

	CMP DL, 40
	JNZ .X_LOOP

	INC DH
	CMP DH, 25
	JNE PRINT_FIELD

	MOV AH, 0x02
	XOR BH, BH
	MOV DH, 11
	MOV DL, 19
	INT 0x10

	MOV WORD[CURSOR_POSITION], DX

	MOV AH, 0x08
	INT 0x10

	MOV WORD[PREVIOUS_ATTRIBUTE], AX

UPDATE_SELECTED:
	MOV AH, 0x09
	MOV AL, BYTE[PREVIOUS_ATTRIBUTE]
	MOV BL, BYTE[PREVIOUS_ATTRIBUTE + 1]
	AND BL, 0x0F
	OR BL, SELECTED_ATTRIBUTE
	XOR BH, BH
	MOV CX, 1
	INT 0x10

GET_KEY:
	CMP WORD[MINE_COUNT], 0
	JZ SAFE_TILES_CLEAR

SAFE_TILES_EXIST:
	XOR AH, AH
	INT 0x16

	OR AL, 0x20

	MOV DX, WORD[CURSOR_POSITION]

	CMP AL, 'd'
	JE MOVE_RIGHT

	CMP AL, 'a'
	JE MOVE_LEFT

	CMP AL, 'w'
	JE MOVE_UP

	CMP AL, 's'
	JE MOVE_DOWN

	CMP AL, 'f'
	JE PLACE_FLAG

	CMP AL, 'c'
	JE CLEAR_FIELD

	CMP AX, 0x013B
	JE EXIT

	JMP GET_KEY

MOVE_LEFT:
	TEST DL, DL
	JZ GET_KEY

	DEC DL
	JMP MOVE_CURSOR

MOVE_RIGHT:
	CMP DL, 39
	JAE GET_KEY

	INC DL
	JMP MOVE_CURSOR

MOVE_UP:
	TEST DH, DH
	JZ GET_KEY

	DEC DH
	JMP MOVE_CURSOR

MOVE_DOWN:
	CMP DH, 24
	JAE GET_KEY

	INC DH

MOVE_CURSOR:
	MOV AH, 0x09
	XOR BH, BH
	MOV AL, BYTE[PREVIOUS_ATTRIBUTE]
	MOV BL, BYTE[PREVIOUS_ATTRIBUTE + 1]
	MOV CX, 1
	INT 0x10

	MOV AH, 0x02
	INT 0x10

	MOV WORD[CURSOR_POSITION], DX

	MOV AH, 0x08
	INT 0x10

	MOV WORD[PREVIOUS_ATTRIBUTE], AX

	JMP UPDATE_SELECTED 

PLACE_FLAG:
	CALL FIELD_DATA_LOCATION	
	MOV AL, BYTE[BX]

	TEST AL, 0x10
	JZ GET_KEY

	XOR AL, 0x40
	MOV BYTE[BX], AL

	TEST AL, 0x40
	JZ .INC

	MOV AL, 0xD5

	TEST AL, 0x20
	JNZ .PLACE

	DEC WORD[MINE_COUNT]
	JMP .PLACE

.INC:
	MOV AL, 0x00

	TEST AL, 0x20
	JNZ .PLACE

	INC WORD[MINE_COUNT]

.PLACE:
	MOV AH, 0x09
	XOR BH, BH
	MOV BL, (SELECTED_ATTRIBUTE & 0xF0) | 0x04
	MOV CX, 1
	INT 0x10

	MOV AH, BYTE[PREVIOUS_ATTRIBUTE + 1]
	AND AH, 0xF0
	AND BL, 0x0F
	OR AH, BL
	MOV WORD[PREVIOUS_ATTRIBUTE], AX
	
	JMP GET_KEY

CLEAR_FIELD:
	MOV DX, WORD[CURSOR_POSITION]
	CALL GET_FIELD_DATA

	TEST AL, 0x10
	JZ GET_KEY

	TEST AL, 0x40
	JNZ GET_KEY

	CALL CLEAR_FIELDS

	TEST AL, 0x20
	JNZ BLOWN_UP

	MOV AH, 0x08
	XOR BH, BH
	INT 0x10

	MOV WORD[PREVIOUS_ATTRIBUTE], AX

	MOV BL, AH
	AND BL, 0x0F
	OR BL, 0xE0
	MOV AH, 0x09
	XOR BH, BH
	MOV CX, 1
	INT 0x10

	JMP GET_KEY

SAFE_TILES_CLEAR:
	CMP WORD[SAFE_TILE_COUNT], 0
	JNZ SAFE_TILES_EXIST

	MOV AX, 0x0003
	INT 0x10

	MOV AH, 0x01
	MOV SI, VICTORY_MSG
	MOV CX, VICTORY_MSG_END - VICTORY_MSG
	INT 0x80

	MOV AH, 0x01
	MOV SI, ANY_KEY_MSG
	MOV CX, ANY_KEY_MSG_END - ANY_KEY_MSG
	INT 0x80

	XOR AH, AH
	INT 0x16

	JMP EXIT

BLOWN_UP:
	MOV AX, 0x0003
	INT 0x10

	MOV AH, 0x01
	MOV SI, DEFEAT_MSG
	MOV CX, DEFEAT_MSG_END - DEFEAT_MSG
	INT 0x80

	MOV SI, ANY_KEY_MSG
	MOV CX, ANY_KEY_MSG_END - ANY_KEY_MSG
	INT 0x80

	XOR AH, AH
	INT 0x16

EXIT:
	MOV AX, 0x0003
	INT 0x10

	XOR AH, AH
	INT 0x80

; DH <- Row.
; DL <- Column.
CLEAR_FIELDS:
	PUSH AX

	CALL GET_FIELD_DATA

	TEST AL, 0x40
	JNZ .EXIT

	TEST AL, 0x10
	JZ .EXIT

	CALL DISPLAY_FIELD_CONTENTS
	DEC WORD[SAFE_TILE_COUNT]

	TEST AL, 0x0F
	JNZ .EXIT

	TEST AL, 0x20
	JNZ .EXIT

	MOV CH, -1

.Y_LOOP:
	MOV CL, -1

.X_LOOP:
	CALL CHECK_IF_LEGAL
	JC .SKIP

	PUSH CX
	PUSH DX
	ADD DH, CH
	ADD DL, CL
	CALL CLEAR_FIELDS
	POP DX
	POP CX

.SKIP:
	INC CL
	CMP CL, 1
	JLE .X_LOOP

	INC CH
	CMP CH, 1
	JLE .Y_LOOP

.EXIT:
	POP AX
	RET

; CH -> y offset.
; CL -> x offset.
; DH -> Row.
; DL -> Column.
CHECK_IF_LEGAL:
	PUSH SI
	PUSH BX
	CALL FIELD_DATA_LOCATION
	MOV SI, BX
	CALL SURROUNDING_IN_FIELD
	POP BX
	POP SI
	RET

; DH <- Row.
; DL <- Column.
DISPLAY_FIELD_CONTENTS:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX

	MOV AH, 0x02
	XOR BH, BH
	INT 0x10

	CALL FIELD_DATA_LOCATION
	MOV AL, BYTE[BX]

	TEST AL, 0x10
	JZ .OUT

	TEST AL, 0x40
	JNZ .OUT	

	XOR AL, 0x10
	MOV BYTE[BX], AL

	CMP AL, 0x20
	JE .MINE

	AND AL, 0x0F
	JZ .EMPTY

	ADD AL, '0'
	JMP .PRINT

.MINE:
	MOV AL, '*'
	JMP .PRINT

.EMPTY:
	MOV AL, ' '

.PRINT:
	MOV AH, 0x09
	XOR BH, BH
	MOV BL, 0xF0
	MOV CX, 1
	INT 0x10

	MOV AH, 0x02
	MOV DX, WORD[CURSOR_POSITION]
	INT 0x10

	TEST AH, AH

.OUT:
	POP DX
	POP CX
	POP BX
	POP AX
	RET

; DH <- Row.
; DL <- Column.
;
; AL -> Field data.
GET_FIELD_DATA:
	PUSH BX

	CALL FIELD_DATA_LOCATION
	MOV AL, BYTE[BX]

	POP BX
	RET

; DH <- Row.
; DL <- Column.
;
; BX -> Field data location.
FIELD_DATA_LOCATION:
	PUSH AX
	PUSH CX
	PUSH DX

	MOV CX, DX

	XOR DX, DX
	MOV AL, CH
	XOR AH, AH
	MOV BX, 40
	MUL BX 

	MOV BL, CL
	XOR BH, BH
	ADD BX, AX
	ADD BX, FIELD

	POP DX
	POP CX
	POP AX
	RET

; CH <- y offset
; CL <- x offset
; SI <- The selected tile to check relatively from.
;
; ZF -> Set if it is a mine.
SURROUNDING_IS_MINE:
	PUSH AX
	PUSH BX
	PUSH DX

	MOV AL, CH
	CALL SIGN_EXTEND

	XOR DX, DX
	MOV BX, 40
	MUL BX

	MOV BX, AX
	ADD BX, SI

	MOV AL, CL
	CALL SIGN_EXTEND

	ADD BX, AX

	CMP BYTE[BX], 0x30

	POP DX
	POP BX
	POP AX
	RET

; AL <- Signed number.
;
; AX -> Extended signed number.
SIGN_EXTEND:
	PUSH BX

	MOV BL, AL
	MOV AH, 0xFF
	ADD AX, 0x0080
	NOT AH
	MOV AL, BL

	POP BX
	RET

; CH <- y offset
; CL <- x offset
; SI <- The selected tile to compare relatively from.
;
; CF -> Cleared if in field.
SURROUNDING_IN_FIELD:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI

	XOR DX, DX

	MOV AL, CH
	CALL SIGN_EXTEND

	MOV BX, 40
	MUL BX

	MOV BX, SI
	SUB BX, FIELD
	ADD BX, AX

	CMP BX, 25 * 40 - 1
	JA .OUTSIDE

	XOR DX, DX
	MOV AX, SI
	SUB AX, FIELD
	MOV BX, 40
	DIV BX

	MOV AL, CL
	CALL SIGN_EXTEND

	ADD AX, DX

	CMP AX, 39
	JA .OUTSIDE

	CLC
	JMP .OUT

.OUTSIDE:
	STC

.OUT:
	POP SI
	POP DX
	POP CX
	POP BX
	POP AX
	RET

; Generates a pseudorandom number.
; AX -> A pseudorandom number.
GET_RANDOM_NUMBER:
	PUSH CX
	PUSH DX
	XOR DX, DX

	MOV AX, WORD[SEED]
	MUL AX
	XCHG AH, AL

	PUSH AX
	MOV AH, 0x00
	INT 0x1A
	POP AX
	ADD AX, DX
	SUB AX, WORD[SEED]
	XCHG AH, AL

	MOV WORD[SEED], AX

	POP DX
	POP CX
	RET

; AL <- Value to set to.
; BX <- Location in memory
; CX <- Times to set to.
MEMSET:
	PUSH BX
	PUSH CX

.LOOP:
	MOV BYTE[BX], AL
	INC BX

	LOOP .LOOP

	POP CX
	POP BX
	RET

ASCII_NUM: TIMES 4 DB 0
MINE_COUNT_MSG: DB "Enter the amount of mines (1 - 1000): "
MINE_COUNT_MSG_END:
VICTORY_MSG: DB "All mines cleared successfully."
VICTORY_MSG_END:
DEFEAT_MSG: DB "You were blown up :(."
DEFEAT_MSG_END:
ANY_KEY_MSG: DB " Press any key to exit."
ANY_KEY_MSG_END:
MINE_COUNT: DW 0
SAFE_TILE_COUNT: DW 0
CURSOR_POSITION: DW 0
PREVIOUS_ATTRIBUTE: DW 0
SEED: DW 0
FIELD:
FIELD_EMPTY_START:
