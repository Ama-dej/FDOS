; AH = 0x31
; BX = X coordinate (less than 320).
; CX = Y coordinate (less than 200).
; DL = Color (lower two bits).
PUT_PIXEL_INT:
        AND DL, 0x03
        MOV AX, 0xB800

        CMP BX, 320
        JAE RET_INT

        CMP CX, 200
        JAE RET_INT

        TEST CX, 1
        JZ .CONTINUE

        ADD AX, 0x200

.CONTINUE:
        MOV ES, AX

        MOV AX, BX
        SHR AX, 2
        MOV DI, AX

        PUSH CX
        PUSH DX
        MOV AX, 80
        SHR CX, 1
        MUL CX
        POP DX
        POP CX

        ADD DI, AX

        MOV AL, BL
        AND AL, 0x03
        SHL AL, 1
        MOV AH, DL

        MOV DL, BYTE[ES:DI]

        MOV CH, 0x03
        MOV CL, 6
        SUB CL, AL
        SHL CH, CL
        SHL AH, CL
        NOT CH
        AND DL, CH

        OR DL, AH

        MOV BYTE[ES:DI], DL

        JMP RET_INT
