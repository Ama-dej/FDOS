; AH = 0x20
; DI = Pointer to 80 byte buffer.
COMMAND_PARAMETERS_INT:
        MOV SI, DS
        MOV ES, SI

        MOV SI, DOS_SEGMENT
        MOV DS, SI
        MOV SI, COMMAND_PARSED

        MOV CX, 80
        CALL MEMCPY

        MOV SI, ES
        MOV DS, SI

        JMP RET_INT
