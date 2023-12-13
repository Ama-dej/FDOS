; AH = 0x30
; Sets the screen to 320 x 200 (CGA mode).
SET_GRAPHICS_MODE_INT:
        MOV AH, 0x00
        MOV AL, 0x04
        INT 0x10

        JMP RET_INT
