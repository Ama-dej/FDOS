; AH = 0x15
; SI = Path to directory.
; This service does nothing more than just jumping to the MAKE FILE INTERRUPT.
; Here for compatibility reasons.
MAKE_DIRECTORY_INT:
	MOV DH, 0x10
	JMP MAKE_FILE_INT
