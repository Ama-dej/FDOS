; Sets the current video mode to the one FDOS booted to.
DOS_TEXT_MODE_INT:
	MOV AX, DOS_SEGMENT
	MOV DS, AX

	XOR AH, AH
	MOV AL, BYTE[BOOT_VIDEO_MODE]
	INT 0x10

	JMP RET_INT
