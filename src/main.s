
;
;   Main code for EWENM4
;	TERMINAL MODE begins here
;
;

term

	LD	A,2
	CALL	SCR_SET_MODE
	
	LD	A,66			; ESC key
	CALL	KM_GET_TRANSLATE	; Get current normal setting
	LD	(ESC_key),A		; Save for later

	LD	A,66			; Set up the ESC key to return
	LD	B,27			; the normal ESC char when pressed
	CALL	KM_SET_TRANSLATE	; without Control/Shift           

	LD	A,9			; COPY key
	CALL	KM_GET_TRANSLATE	; Get current normal setting
	LD	(COPY_key),A		; Save for later

	LD	A,9			; Set up the COPY key to return
	LD	B,255			; an invalid number when pressed
	CALL	KM_SET_TRANSLATE	; without Control/Shift

	LD	A,16			; CLR key
	CALL	KM_GET_TRANSLATE
	LD	(CLR_key),A

	LD	A,16			; Make it send CTRL-G
	LD	B,7
	CALL	KM_SET_TRANSLATE

	CALL	AllOff

	LD	A,12			; Clear screen, and buffer
	CALL	ToScreen

	LD	HL,0			; No offset, just set mode
	LD	(ScreenOffset),HL


    CALL	SetCursorInterupt	; Turn on interupt!


	JP start_telnet


	
;----------------------------------------
;
;	PRINT CHARACTER
;
;	This routine handles printing
;	a character to the screen
;	Entry - A = Charcter
;	Exit  - Ignore if A = 0
;	Used  - None
;
;----------------------------------------
JLocalEcho
	DEFB	#C9			; Local echo location 0 means on
PrintChar
	PUSH	AF			; Save AF
	PUSH	HL			; Save HL
	LD	H,HighLocalTrans	; Put through translation table
	LD	L,A
	LD	A,(HL)			; Now use the value!

	OR	A
	JP	Z,PCexit

PrintC1
	CP	9			; Is it TAB?
	JP	NZ,PC1
	CALL	JLTabExpand
	JP	PCexit
PC1	CALL	ToScreen		; Print the character
	CP	8			; Is it DEL?
	CALL	Z,JLDestDel
	CP	13			; Is it RET?
	CALL	Z,JLAddLF
PCexit	POP	HL			; Restore HL
	POP	AF			; Restore AF
	RET

;----------------------------------------
;
;	LOCAL DESTRUCTIVE DELETE
;
;	This echos a 32 then an 8 to go
;	with the other 8, overwriting
;	the space
;	Entry - None
;	Exit  - None
; 	Used  - AF
;
;-----------------------------------------
JLDestDel
	DEFB	#C9			; Destructive Delete (Local)
LocalDestDel
	LD	A,32
	CALL	ToScreen
	LD	A,8
	JP	ToScreen

;------------------------------------------
;
;	LOCAL ADD LF TO CR
;
;	This will add a LF to the previously
;	printed CR
;	Entry - None
;	Exit  - None
;	Used  - AF
;
;-------------------------------------------
JLAddLF
	DEFB	#c9	;#C9		; Local Add LF to CR 0 means on
LocalAddLF
	LD	A,10
	JP	ToScreen

;--------------------------------------------
;
;	LOCAL TAB EXPANDER
;
;	This will expand a TAB to a string
;	of spaces TAB stops set at every 8
;	Entry - None
;	Exit  - None
;	Used  - AF
;
;---------------------------------------------
JLTabExpand
	DEFB	0			; Local Tab Expander, #c9 means off
LocalTabExpand
	PUSH	HL
	CALL	TXT_GET_CURSOR
	LD	A,H			; Put column in A
	CP	72			; Is it greater than last tab stop?
	JR	NC,lt4			; If so then replace it with a
					; CR
	DEC	A			; Convert from Logical to Physical
					; coordinates, ie left edge = 0
lt1	CP	8			; Is it less than 8
	JR	C,lt2
	SUB	A,8			; Reduce A by 8
	JP	lt1			; Go and check again
lt2	LD	B,A			; B = 8 - A
	LD	A,8
	SUB	B
	LD	B,A
	LD	A,32
lt3	CALL	ToScreen		; Send it to the screen
	DJNZ	lt3
	POP	HL			; Restore HL
	RET
lt4	LD	A,13			; Print a CR (with LF if on)
	CALL	ToScreen
	POP	HL
	RET


