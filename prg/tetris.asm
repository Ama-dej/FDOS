CPU 8086
[BITS 16]
[ORG 0x0000]

%DEFINE TETROMINO_OFFSET 0x010E ; y : x offset of the field and other stuff.
%DEFINE SCORE_OFFSET 0x0B1D
%DEFINE PAUSED_MESSAGE_LOC 0x0B03
%DEFINE TICK_DELAY 4

JMP SHORT PROG_START
VERSION: DB 0
SIGNATURE: DW 0xFD05
DB 0xAA
TARGET_SEGMENT: DW 0x0C80
STACK_SEGMENT: DW 0x0C00
STACK_POINTER: DW 0x0800

PROG_START:
JMP SETUP

SETUP:
	INT 0x11
        AND AX, 0x0030
        CMP AX, 0x0030
        JNE .CGA

	MOV BX, TETROMINO_COLOURS
	MOV CX, 7

.LOOP:
	MOV BYTE[BX], 0x78

	INC BX
	LOOP .LOOP

.CGA:
	MOV AH, 0x00
	MOV AL, 0x01
	INT 0x10 ; Change to 40x25.

	MOV AH, 0x01
	MOV CX, 0x2607
	INT 0x10 ; Make the cursor invisible.

	MOV AX, 0x1003
	MOV BL, 0x00
	INT 0x10 ; Turn off blinking attribute. 

	; http://www.techhelpmanual.com/140-int_10h_1003h__select_foreground_blink_or_bold_background.html
        MOV AX, 0x40
        MOV ES, AX
        MOV DX, WORD[ES:0x63]
        ADD DX, 4
        MOV AL, BYTE[ES:0x65]
        AND AL, 0xDF
        OUT DX, AL
        MOV BYTE[ES:0x65], AL ; Turn off blinking attribute (MDA, CGA).

        MOV DX, 0x3D8
        IN AL, DX
        AND AL, 0x1F
        OUT DX, AL

	XOR BX, BX
	MOV ES, BX
	MOV BX, 0x1C * 4

	MOV DX, WORD[ES:BX]
	MOV WORD[ORIGINAL_ISR_OFFSET], DX
	MOV DX, WORD[ES:BX + 2]
	MOV WORD[ORIGINAL_ISR_SEGMENT], DX

	CLI
	MOV WORD[ES:BX], TIMER_ISR
	MOV WORD[ES:BX + 2], DS
	STI

	MOV BX, 0x0007

	MOV AL, 0xC9
	MOV DL, (TETROMINO_OFFSET & 0xFF) - 1
	MOV DH, 0
	MOV CX, 1
	CALL WRITE_CHAR ; Corner character of the border.

	MOV AL, 0xCD
	MOV DL, TETROMINO_OFFSET & 0xFF 
	MOV CX, 17
	CALL WRITE_CHAR ; Top side of the border.

	MOV AH, 0x02
	XOR BX, BX
	MOV DH, (TETROMINO_OFFSET >> 8) - 1
	MOV DL, (TETROMINO_OFFSET & 0xFF) + 12
	INT 0x10 ; "NEXT" string position.

	MOV AH, 0x01
	MOV SI, NEXT_MSG
	MOV CX, 4
	INT 0x20

	MOV BX, 0x0007

	MOV AL, 0xCB
	MOV DL, (TETROMINO_OFFSET & 0xFF) + 10
	MOV CX, 1
	CALL WRITE_CHAR ; More border characters...

	MOV AL, 0xCD
	MOV DH, 5
	MOV DL, (TETROMINO_OFFSET & 0xFF) + 11
	MOV CX, 6
	CALL WRITE_CHAR

	MOV AL, 0xBA
	MOV DH, 1
	MOV DL, (TETROMINO_OFFSET & 0xFF) + 17
	MOV CX, 1
	MOV DI, 4

.NEXT_DRAW_LOOP: ; This draws the border around the next tetromino.
	CALL WRITE_CHAR
	INC DH

	DEC DI
	JNZ .NEXT_DRAW_LOOP

	MOV CX, 1
	MOV DI, 23
	MOV DH, 1 
	MOV AL, 0xBA

BORDER_LOOP:
	MOV DL, (TETROMINO_OFFSET & 0xFF) - 1 
	CALL WRITE_CHAR

	MOV DL, (TETROMINO_OFFSET & 0xFF) + 10 
	CALL WRITE_CHAR

	INC DH
	DEC DI
	JNZ BORDER_LOOP

	MOV AL, 0xCC
	MOV DH, 5
	MOV DL, (TETROMINO_OFFSET & 0xFF) + 10
	MOV CX, 1 
	CALL WRITE_CHAR

	MOV AL, 0xBC
	ADD DL, 7
	CALL WRITE_CHAR

	MOV AL, 0xBB
	SUB DH, 5
	CALL WRITE_CHAR
	
	MOV AL, 0xC8
	MOV DL, (TETROMINO_OFFSET & 0xFF) - 1
	MOV DH, 24 
	MOV CX, 1
	CALL WRITE_CHAR

	MOV AL, 0xCD
	MOV DL, TETROMINO_OFFSET & 0xFF 
	MOV CX, 10
	CALL WRITE_CHAR

	MOV AL, 0xBC
	MOV DL, (TETROMINO_OFFSET & 0xFF) + 10
	MOV CX, 1
	CALL WRITE_CHAR

	MOV AH, 0x02
	XOR BX, BX
	MOV DX, SCORE_OFFSET - 0x0100 
	INT 0x10 

	MOV AH, 0x01
	MOV SI, LINES
	MOV CX, 6
	INT 0x20

	MOV AH, 0x02
	MOV DX, ((SCORE_OFFSET & 0xFF00) + 0x0300) | ((SCORE_OFFSET & 0x00FF) - 2)
	INT 0x10

	MOV AH, 0x01
	MOV SI, HIGH
	MOV CX, 11
	INT 0x20

	JMP GEN_FIRST_PIECE

NEW_PIECE:
	MOV AH, 0x00
	INT 0x1A ; Get clock ticks since midnight.

	PUSH DX

	MOV AH, 0x02
	INT 0x1A ; Get current time.

	POP AX
	ADD AX, DX ; Add the clock ticks and time together.
	XOR DX, DX

	MOV BX, 7
	DIV BX ; Divide by 7 to get the index of the tetromino.

	MOV BL, BYTE[NEXT_TETROMINO_COLOUR]
	MOV BYTE[TETROMINO_COLOUR], BL ; Update the colour.

	MOV BX, TETROMINO_COLOURS
	ADD BX, DX
	MOV AL, BYTE[BX]
	MOV BYTE[NEXT_TETROMINO_COLOUR], AL ; Get the new colour for the next tetromino.

	; SHL DX, 5 ; Multiply by 32 (because each tetromino is 32 bytes large).
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	ADD DX, I_TETROMINO

	MOV AX, WORD[NEXT_TETROMINO]
	MOV WORD[TETROMINO_CUR_BUFFER], AX ; The current tetromino becomes the next one.
	MOV WORD[TETROMINO_PREV_BUFFER], AX 

	MOV WORD[NEXT_TETROMINO], DX ; Update the next tetromino.

	MOV WORD[TETROMINO_COORDS], 0x0004 ; Reset the coords to the top of the field.
	MOV WORD[TETROMINO_PREV_COORDS], 0x0004

	MOV WORD[TETROMINO_ROTATION], 0

	XOR BX, BX
	MOV DX, ((TETROMINO_OFFSET + 0x100) & 0xFF00) | ((TETROMINO_OFFSET + 12) & 0x00FF)

	MOV DI, 4
	MOV CX, 2

.CLEAR_LOOP: ; Clear the previous next tetromino to make place for the new one.
	CALL WRITE_BLOCK

	INC DL
	DEC DI
	JNZ .CLEAR_LOOP

	MOV DI, 4
	INC DH
	SUB DL, 4

	DEC CX
	JNZ .CLEAR_LOOP

	MOV BX, WORD[NEXT_TETROMINO]
	MOV DI, 4

.WRITE_LOOP: ; Then write the next tetromino.
	MOV DX, WORD[BX]
	ADD DL, 12 
	ADD DH, 1
	ADD DX, TETROMINO_OFFSET

	PUSH BX
	XOR BH, BH
	MOV BL, BYTE[NEXT_TETROMINO_COLOUR]
	CALL WRITE_BLOCK
	POP BX

	ADD BX, 2

	DEC DI
	JNZ .WRITE_LOOP

	JMP MOVE

START:
	MOV AH, 0x01
	INT 0x16 ; Check if a key is pressed.

	JZ DELAY ; If not do nothing.

	MOV AH, 0x00
	INT 0x16 ; Get the key.

SKIP_INPUT:
	CMP AH, 0x48 ; Up arrow.
	JE UP_PRESSED

	CMP AH, 0x50 ; Down arrow.
	JE DOWN_PRESSED

	CMP AH, 0x4B ; Left arrow.
	JE LEFT_PRESSED

	CMP AH, 0x4D ; Right arrow.
	JE RIGHT_PRESSED

	CMP AL, 0
	JE DELAY

	CMP AX, 0x011B
	JE EXIT

	OR AL, 0b00100000 ; Convert to lowercase (so it works even if caps lock is on).

	CMP AL, 'w'
	JE UP_PRESSED

	CMP AL, 's'
	JE DOWN_PRESSED

	CMP AL, 'a'
	JE LEFT_PRESSED

	CMP AL, 'd'
	JE RIGHT_PRESSED

	CMP AL, ' '
	JE SPACE_PRESSED

	CMP AL, 'p'
	JE P_PRESSED

	JMP DELAY

P_PRESSED: ; Pause the game.
	CMP WORD[PAUSED_DELAY], 0 ; So you can't spam the pause key.
	JNZ DELAY

	MOV AX, TICK_DELAY
	MOV WORD[PAUSED_DELAY], AX ; Reset the delay.

	MOV AH, 0x02
	XOR BX, BX
	MOV DX, PAUSED_MESSAGE_LOC 
	INT 0x10 ; Change cursor location to the left side of the screen.

	MOV AH, 0x01
	MOV SI, PAUSED_MSG
	MOV CX, 6
	INT 0x20

.WAIT_FOR_P_PRESS:
	MOV AH, 0x00 
	INT 0x16

	OR AL, 0b00100000

	CMP AL, 'p'
	JNE .WAIT_FOR_P_PRESS

	MOV AH, 0x02
	XOR BX, BX
	MOV DX, PAUSED_MESSAGE_LOC 
	INT 0x10 ; Change cursor back to clear the string.

	MOV AH, 0x01
	MOV SI, CLEAR_PAUSED_MSG
	MOV CX, 6
	INT 0x20

	JMP DELAY

UP_PRESSED:
	ADD WORD[TETROMINO_ROTATION], 8 ; "Rotate" right (each tetromino image is 8 bytes large).
	AND WORD[TETROMINO_ROTATION], 0x001F ; So it doesn't overflow.

	JMP CHECK_MOVE 

SPACE_PRESSED: ; Hard drop.
	MOV BX, WORD[TETROMINO_CUR_BUFFER]
	ADD BX, WORD[TETROMINO_ROTATION]

.NEXT_Y: ; Go for 1 Y down until you hit something.
	INC BYTE[TETROMINO_Y]
	PUSH BX
	MOV DI, 4

.CHECK_OVERLAP:	
	MOV DX, WORD[BX]

	PUSH BX

	MOV BX, FIELD_DATA
	ADD DH, BYTE[TETROMINO_Y]
	; MOVZX CX, DH
	MOV CL, DH
	XOR CH, CH
	SHL CX, 1
	ADD BX, CX ; Get the corresponding field data.

	MOV AX, WORD[BX]
	ADD DL, BYTE[TETROMINO_X]
	MOV CL, 9
	SUB CL, DL
	SHR AX, CL ; This is done by shifting the bit in the y coordinate of the block by x times to the right.
	AND AX, 0x0001

	POP BX
	JNZ WRITE_TO_FIELD ; If there is a one it means our piece overlaps. 
	ADD BX, 2

	DEC DI
	JNZ .CHECK_OVERLAP

	POP BX
	CALL UPDATE_PIECE
	JMP .NEXT_Y

LEFT_PRESSED:
	DEC BYTE[TETROMINO_X] ; If we want to go left decrement the X coordinate.

	JMP CHECK_MOVE 

RIGHT_PRESSED:
	INC BYTE[TETROMINO_X] ; Same thing as going left but instead increment.

	JMP CHECK_MOVE 

DOWN_PRESSED:
	INC BYTE[TETROMINO_Y] ; Go down.

	MOV BX, WORD[TETROMINO_CUR_BUFFER]
	ADD BX, WORD[TETROMINO_ROTATION]
	MOV DI, 4

	PUSH BX

.CHECK_OVERLAP: ; Checks if the piece overlaps. 
	MOV DX, WORD[BX]

	PUSH BX

	MOV BX, FIELD_DATA
	ADD DH, BYTE[TETROMINO_Y]
	; MOVZX CX, DH
	MOV CL, DH
	XOR CH, CH
	SHL CX, 1
	ADD BX, CX ; Get the corresponding field data.

	MOV AX, WORD[BX]
	ADD DL, BYTE[TETROMINO_X]
	MOV CL, 9
	SUB CL, DL
	SHR AX, CL ; This is done by shifting the bit in the y coordinate of the block by x times to the right.
	AND AX, 0x0001

	POP BX
	JNZ WRITE_TO_FIELD ; If there is a one it means our piece overlaps. 
	ADD BX, 2

	DEC DI
	JNZ .CHECK_OVERLAP

	POP BX
	JMP MOVE 

WRITE_TO_FIELD:
	DEC BYTE[TETROMINO_Y]
	POP BX
	PUSH BX
	MOV DI, 4

.WRITE_LOOP:
	MOV DX, WORD[BX]

	PUSH BX

	MOV BX, FIELD_DATA
	ADD DH, BYTE[TETROMINO_Y]
	; MOVZX CX, DH
	MOV CL, DH
	XOR CH, CH
	SHL CX, 1
	ADD BX, CX ; Get the corresponding field data.

	ADD DL, BYTE[TETROMINO_X]
	MOV CL, 9 
	SUB CL, DL
	MOV DX, 1
	SHL DX, CL ; Write to the field with the same logic as before.
	OR WORD[BX], DX

	POP BX
	ADD BX, 2

	DEC DI
	JNZ .WRITE_LOOP

	POP BX

	MOV DX, WORD[BX]

	MOV BX, FIELD_DATA
	ADD DH, BYTE[TETROMINO_Y]
	; MOVZX CX, DH
	MOV CL, DH
	XOR CH, CH
	SHL CX, 1
	ADD BX, CX

	MOV DI, 4

.CLEAR_ROW:
	PUSH BX

	MOV AX, WORD[BX]
	CMP AX, 0x03FF ; Check if the row is full.
	JNE .UPDATE_OUT

	INC WORD[SCORE] ; Increment the score by one.

.UPDATE_LOOP:
	MOV AX, WORD[BX - 2]
	MOV WORD[BX], AX ; Move the field one down.

	PUSH AX
	PUSH BX

	SUB BX, FIELD_DATA
	SHR BX, 1
	MOV DH, BL
	MOV DL, TETROMINO_OFFSET & 0xFF
	XOR BX, BX
	MOV CL, 10

	ADD DH, (TETROMINO_OFFSET >> 8) & 0xFF
	DEC DH

.UPDATE_GRAPHICS: ; Now we also have to update the graphics.
	MOV AH, 0x02
	INT 0x10

	MOV AH, 0x08
	INT 0x10

	INC DH

	; MOVZX BX, AH
	MOV BL, AH
	XOR BH, BH
	CALL WRITE_BLOCK

	DEC DH
	INC DL
	DEC CL
	JNZ .UPDATE_GRAPHICS

	POP BX
	POP AX

	OR AX, AX
	JZ .UPDATE_OUT ; Do this until we find an empty field space.

	SUB BX, 2
	JMP SHORT .UPDATE_LOOP

.UPDATE_OUT:
	POP BX
	ADD BX, 2

	DEC DI
	JNZ .CLEAR_ROW

	MOV AH, 0x02
	XOR BX, BX
	MOV DX, SCORE_OFFSET 
	INT 0x10 

	MOV AX, WORD[SCORE]
	CALL ITOA ; Update the score.

	PUSH AX
	; PUSH SI
	MOV AH, 0x01
	MOV SI, ASCII_NUM
	MOV CX, 5
	INT 0x20
	; POP SI
	POP AX

	; AND AX, 0x000F
	; JNZ .NO_DECREASE ; Every 16 lines cleared increase the falling speed.

	; CMP WORD[FALL_DELAY], 1 ; If the falling speed is already to high then don't.
	; JLE .NO_DECREASE

	; SUB WORD[FALL_DELAY], 1

.NO_DECREASE:
	OR WORD[FIELD_DATA + 2], 0
	JNZ GAME_OVER ; if the second row of the field from the top has something in it, it's game over.

	JMP NEW_PIECE
	
CHECK_MOVE: ; Basically check if any of the pieces are out of bounds.
	MOV BX, WORD[TETROMINO_CUR_BUFFER]
	ADD BX, WORD[TETROMINO_ROTATION]
	MOV DI, 4

.CHECK_LOOP:
	MOV DX, WORD[BX]
	ADD DX, WORD[TETROMINO_COORDS]

	CMP DL, 0
	JL REVERT

	CMP DL, 10 ; Checks if the y coordinate of each block is inside the field.
	JGE REVERT ; If it's not we have to revert the piece to it's previous position.

	ADD BX, 2

	DEC DI
	JNZ .CHECK_LOOP

	MOV BX, WORD[TETROMINO_CUR_BUFFER]
	ADD BX, WORD[TETROMINO_ROTATION]
	MOV DI, 4

.CHECK_OVERLAP: ; We also have to prevent rotating the tetromino into pieces.
	MOV DX, WORD[BX]

	PUSH BX

	MOV BX, FIELD_DATA
	ADD DH, BYTE[TETROMINO_Y]
	; MOVZX CX, DH
	MOV CL, DH
	XOR CH, CH
	SHL CX, 1
	ADD BX, CX

	MOV AX, WORD[BX]
	ADD DL, BYTE[TETROMINO_X]
	MOV CL, 9
	SUB CL, DL
	SHR AX, CL ; This is done with the same logic as when the piece moves down.
	AND AX, 0x0001

	POP BX
	JNZ REVERT 
	ADD BX, 2

	DEC DI
	JNZ .CHECK_OVERLAP

	JMP MOVE

REVERT:
	MOV AX, WORD[TETROMINO_PREV_BUFFER]
	SUB AX, WORD[TETROMINO_CUR_BUFFER]
	MOV WORD[TETROMINO_ROTATION], AX ; Reset the rotation.

	MOV AX, WORD[TETROMINO_PREV_COORDS]
	MOV WORD[TETROMINO_COORDS], AX ; Set to the previous position.

	JMP DELAY

MOVE:
	CALL UPDATE_PIECE

DELAY:
	; MOV AH, 0x86
	; XOR CX, CX
	; MOV DX, 0x03E8
	; INT 0x15 ; Wait for 1ms.

	; MOV AH, 0x22
	; MOV CX, 1
	; INT 0x20

	OR WORD[PAUSED_DELAY], 0
	JZ .SKIP
	DEC WORD[PAUSED_DELAY]

.SKIP:
	; INT 0x1C

	CMP WORD[FALL_DELAY], 0
	JNZ START
	MOV WORD[FALL_DELAY], TICK_DELAY

	; DEC SI
	; JNZ START ; Wait N times for 1ms so it looks like a N ms delay.

	; MOV SI, WORD[FALL_DELAY] ; Reset the counter.
	; MOV AL, ' ' ; It's stupid but it works.
	JMP DOWN_PRESSED 

GAME_OVER:
	MOV AH, 0x02
	XOR BX, BX
	MOV DX, 0x0A11
	INT 0x10 ; Change cursor location to around the middle of the screen.

	MOV AH, 0x01
	MOV SI, GAME
	MOV CX, 4
	INT 0x20 ; Print "Game".

	MOV AH, 0x02
	MOV DX, 0x0D11
	INT 0x10 ; Move down a bit.

	MOV AH, 0x01
	MOV SI, OVER
	MOV CX, 4
	INT 0x20 ; Print "over".

	MOV AX, WORD[SCORE]
	CMP AX, WORD[HIGH_SCORE] ; Check if the score is higher than the high score.

	JLE NOT_BEATEN	

	MOV WORD[HIGH_SCORE], AX ; If it is update it.
	CALL SAVE_HIGH_SCORE

NOT_BEATEN:
	XOR AX, AX
	MOV WORD[SCORE], AX
	CALL ITOA

	MOV BX, FIELD_DATA
	MOV DI, 23

.CLEAR_FIELD_DATA: ; We have to set the field to zeros.
	MOV WORD[BX], 0
	ADD BX, 2

	DEC DI
	JNZ .CLEAR_FIELD_DATA

	; MOV AH, 0x86
	; MOV CX, 0x0007 
	; MOV DX, 0xA120 
	; INT 0x15 ; Wait for 500ms.

	MOV AH, 0x00
	INT 0x16

	CMP AX, 0x011B
	JE EXIT

	MOV DX, TETROMINO_OFFSET
	MOV BX, 0x0007

	MOV CX, 10
	MOV DI, 23

.CLEAR_FIELD_GRAPHICS: ; Then visually clear the field.
	CALL WRITE_BLOCK

	INC DL
	DEC CX 
	JNZ .CLEAR_FIELD_GRAPHICS

	MOV DL, TETROMINO_OFFSET & 0xFF
	INC DH
	MOV CX, 10 

	DEC DI
	JNZ .CLEAR_FIELD_GRAPHICS

	MOV WORD[FALL_DELAY], TICK_DELAY

GEN_FIRST_PIECE: ; When we start a new game there are some things we have to do first.
	MOV AH, 0x02
	XOR BX, BX
	MOV DX, SCORE_OFFSET
	INT 0x10

	MOV AH, 0x01
	MOV SI, ASCII_NUM
	MOV CX, 5
	INT 0x20 ; Print the scores for the first time.
	
	MOV AH, 0x02
	MOV DX, SCORE_OFFSET + 0x0400
	INT 0x10

	MOV AX, WORD[HIGH_SCORE]
	CALL ITOA ; Don't forget about the high score.

	MOV AH, 0x01
	MOV SI, ASCII_NUM
	MOV CX, 5
	INT 0x20

	; MOV SI, WORD[FALL_DELAY] 

	MOV AH, 0x02
	INT 0x1A ; Generate the first piece.

	MOV AX, DX
	XOR DX, DX

	MOV BX, 7
	DIV BX 

	MOV BX, TETROMINO_COLOURS
	ADD BX, DX
	MOV AL, BYTE[BX]
	MOV BYTE[NEXT_TETROMINO_COLOUR], AL ; Same logic as the code under the NEW_PIECE label.

	; SHL DX, 5
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	SHL DX, 1
	ADD DX, I_TETROMINO
	MOV WORD[NEXT_TETROMINO], DX

	JMP NEW_PIECE 

HALT:
	HLT
	JMP SHORT HALT

UPDATE_PIECE:
	; PUSHA
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI

	MOV BX, WORD[TETROMINO_PREV_BUFFER]
	MOV DI, 4

.CLEAR_LOOP: ; First clear the previous location.
	MOV DX, WORD[BX]
	ADD DL, BYTE[TETROMINO_PREV_X] 
	ADD DH, BYTE[TETROMINO_PREV_Y]
	ADD DX, TETROMINO_OFFSET

	PUSH BX
	MOV BX, 0x0007
	CALL WRITE_BLOCK
	POP BX

	ADD BX, 2

	DEC DI
	JNZ .CLEAR_LOOP

	MOV BX, WORD[TETROMINO_CUR_BUFFER]
	ADD BX, WORD[TETROMINO_ROTATION]
	MOV DI, 4

.WRITE_LOOP: ; Then write the new location.
	MOV DX, WORD[BX]
	ADD DL, BYTE[TETROMINO_X]
	ADD DH, BYTE[TETROMINO_Y]
	ADD DX, TETROMINO_OFFSET

	PUSH BX
	XOR BH, BH
	MOV BL, BYTE[TETROMINO_COLOUR]
	CALL WRITE_BLOCK
	POP BX

	ADD BX, 2

	DEC DI
	JNZ .WRITE_LOOP

	SUB BX, 8
	MOV WORD[TETROMINO_PREV_BUFFER], BX
	MOV AX, WORD[TETROMINO_COORDS]
	MOV WORD[TETROMINO_PREV_COORDS], AX

	; POPA
	POP DI
	POP SI
	POP DX
	POP CX
	POP BX
	POP AX
	RET

EXIT:
	XOR BX, BX
	MOV ES, BX
	MOV BX, 0x1C * 4

	CLI
	MOV DX, WORD[ORIGINAL_ISR_OFFSET]
	MOV WORD[ES:BX], DX
	MOV DX, WORD[ORIGINAL_ISR_SEGMENT]
	MOV WORD[ES:BX + 2], DX
	STI

	MOV AX, WORD[SCORE]
	CMP AX, WORD[HIGH_SCORE]
	JLE .CONTINUE

	MOV WORD[HIGH_SCORE], AX
	CALL SAVE_HIGH_SCORE

.CONTINUE:
	MOV AH, 0x30
	INT 0x20

	XOR AH, AH
	INT 0x20

; Writes a coloured block at a given location.
;
; BH -> Page.
; BL -> Colour.
; DH -> Row.
; DL -> Column.
WRITE_BLOCK:
	PUSH AX
	PUSH CX

	MOV AH, 0x02
	INT 0x10

	MOV AH, 0x09
	MOV AL, ' '
	MOV CX, 1
	INT 0x10

	POP CX
	POP AX
	RET

; Writes n amount of characters at a given location.
;
; AL -> Character.
; BH -> Page.
; BL -> Colour.
; DH -> Row.
; DL -> Column.
; CX -> Count.
WRITE_CHAR:
	PUSH AX
	MOV AH, 0x02
	INT 0x10
	POP AX

	PUSH AX
	MOV AH, 0x09
	INT 0x10
	POP AX

	RET

; Converts an integer to a buffer in memory.
; AX -> Number.
ITOA:
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI

	MOV BX, SCORE - 1
	MOV CX, 10
	MOV DI, 5

.LOOP:
	XOR DX, DX
	DIV CX

	ADD DL, 48
	MOV BYTE[BX], DL
	DEC BX

	DEC DI
	JNZ .LOOP

.OUT:
	POP DI
	POP SI
	POP DX
	POP CX
	POP BX
	POP AX
	RET

SAVE_HIGH_SCORE:
	; PUSHA
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	PUSH DI

	MOV AH, 0x11
	MOV BX, WORD[TARGET_SEGMENT]
	MOV ES, BX
	MOV BX, HIGH_SCORE
	MOV CX, 2
	MOV DX, HIGH_SCORE
	XOR DI, DI
	MOV SI, FILENAME
	INT 0x20

	; POPA
	POP DI
	POP SI
	POP DX
	POP CX
	POP BX
	POP AX
	RET

TIMER_ISR:
	PUSH AX
	PUSH DS

	MOV AX, 0x0C80
	MOV DS, AX

	MOV AX, WORD[FALL_DELAY]
	TEST AX, AX
	JZ .EXIT
	
	DEC AX
	MOV WORD[FALL_DELAY], AX

.EXIT:
	POP DS
	POP AX
	IRET

ORIGINAL_ISR_OFFSET: DW 0
ORIGINAL_ISR_SEGMENT: DW 0

DRIVE_NUMBER: DB 0
FILENAME: DB "TETRIS.PRG", 0x00

HIGH_SCORE: TIMES 2 DB 0
NEXT_MSG: DB "NEXT"
GAME: DB "Game"
OVER: DB "over"
LINES: DB "Lines:"
HIGH: DB "High score:"
PAUSED_MSG: DB "Paused"
CLEAR_PAUSED_MSG: DB "      "

PAUSED_DELAY: DW 0

ASCII_NUM: DB "00000"

SCORE: DW 0
FALL_DELAY: DW TICK_DELAY

NEXT_TETROMINO: DW 0
NEXT_TETROMINO_COLOUR: DB 0

TETROMINO_COORDS:
TETROMINO_X: DB 0
TETROMINO_Y: DB 0

TETROMINO_PREV_COORDS:
TETROMINO_PREV_X: DB 0
TETROMINO_PREV_Y: DB 0

TETROMINO_COLOUR: DB 0
TETROMINO_ROTATION: DW 0

TETROMINO_CUR_BUFFER: DW 0
TETROMINO_PREV_BUFFER: DW 0

; Offsets for each tetromino.
I_TETROMINO:
DW 0x0100, 0x0101, 0x0102, 0x0103
DW 0x0002, 0x0102, 0x0202, 0x0302
DW 0x0200, 0x0201, 0x0202, 0x0203
DW 0x0001, 0x0101, 0x0201, 0x0301
J_TETROMINO:
DW 0x0000, 0x0100, 0x0101, 0x0102
DW 0x0001, 0x0002, 0x0101, 0x0201
DW 0x0100, 0x0101, 0x0102, 0x0202
DW 0x0001, 0x0101, 0x0200, 0x0201
L_TETROMINO:
DW 0x0002, 0x0100, 0x0101, 0x0102
DW 0x0001, 0x0101, 0x0201, 0x0202
DW 0x0100, 0x0101, 0x0102, 0x0200
DW 0x0000, 0x0001, 0x0101, 0x0201
O_TETROMINO:
DW 0x0001, 0x0002, 0x0101, 0x0102
DW 0x0001, 0x0002, 0x0101, 0x0102
DW 0x0001, 0x0002, 0x0101, 0x0102
DW 0x0001, 0x0002, 0x0101, 0x0102
S_TETROMINO:
DW 0x0001, 0x0002, 0x0100, 0x0101
DW 0x0001, 0x0101, 0x0102, 0x0202
DW 0x0101, 0x0102, 0x0200, 0x0201
DW 0x0000, 0x0100, 0x0101, 0x0201
T_TETROMINO:
DW 0x0001, 0x0100, 0x0101, 0x0102
DW 0x0001, 0x0101, 0x0102, 0x0201
DW 0x0100, 0x0101, 0x0102, 0x0201
DW 0x0001, 0x0100, 0x0101, 0x0201
Z_TETROMINO:
DW 0x0000, 0x0001, 0x0101, 0x0102
DW 0x0002, 0x0101, 0x0102, 0x0201
DW 0x0100, 0x0101, 0x0201, 0x0202
DW 0x0001, 0x0100, 0x0101, 0x0200

; Give them some nice colours.
TETROMINO_COLOURS:
DB 0xB7
DB 0x17
DB 0x67
DB 0xE7
DB 0xA7
DB 0xD7
DB 0x47

FIELD_DATA:
TIMES 23 DW 0
DW 0xFFFF
