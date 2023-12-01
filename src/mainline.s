PRINT "MAINLINE CODE"
;
;	TERMINAL MODE begins here
;
;

term

	LD	A,2
	CALL	SCR_SET_MODE

	; CALL	KL_U_ROM_DISABLE	; Disable upper rom
	; LD	(RomState),A

	CALL	SetBuf			; Setup buffering
	
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
	LD	IY,DataAreaHere		; Data area of program

	LD	A,12			; Clear screen, and buffer
	CALL	ToScreen

	LD	HL,0			; No offset, just set mode
	LD	(ScreenOffset),HL


   CALL	SetCursorInterupt	; Turn on interupt!


	CALL start_telnet






;----------------------------------------
;
;	EXIT
;
;	This routine exits the terminal
;	program normally
;	Entry - None
;	Exit  - Never returns
;	Used  - AF,BC,HL
;----------------------------------------

	
exit

	LD	A,(ESC_key)		; Restore ESC key to normal
	LD	B,A
	LD	A,66
	CALL	KM_SET_TRANSLATE
	LD	A,(COPY_key)		; Restore Copy key to normal
	LD	B,A
	LD	A,9
	CALL	KM_SET_TRANSLATE
	LD	A,(CLR_key)		; Restore CLR key
	LD	B,A
	LD	A,16
	CALL	KM_SET_TRANSLATE
;	CALL	TXT_CUR_OFF		; Cursor off
;	CALL	ToggleCursor		; Cursor now off
Exit_1
;	CALL	AllOff			; All attributes off  - ON ENTRY -
;	CALL	ClearBuffer		; Clear out the buffers, and
					; delete fast ticker block
	LD	HL,Signoff_terminal	; Signoff message
	CALL	prints			; And back to Basic
	LD	A,1
	LD	(DKeyboard),A
	LD	A,#C9
	LD	(JAnsi),A
	XOR	A
	LD	(JScrnBuf),A
	LD	(JScreenWrite),A
;	CALL	JCloseFile
	CALL	OffCursorInterupt
	LD	A,(RomState)
	CALL	KL_ROM_RESTORE
	XOR	A
	LD	(HaveLoaded),A
	LD	HL,NumberBuffer
	LD	(NumberPos),HL
	RET



;----------------------------------------
;
;	SENDOUT
;
;	This routine outputs characters
;	to the modem
;       Entry - A = Character
;	Exit  - None
;	Used  - None
;
;----------------------------------------
JRemoteEcho
	DEFB	#C9			; Remote echo location 0 means on
SendOut
	PUSH	AF			; Save registers
	PUSH	HL
;	LD	H,HighRemoteBlock	; Put character through block mask
;	LD	L,A                     ; Will be zero if masked out
;	LD	A,(HL)
;	OR	A
;	JR	Z,SOexit		; If masked then exit now
; *** 22b - back to old translation tables  Seems better

	LD	H,HighRemoteTrans	; Put through translation table
	LD	L,A
	LD	A,(HL)			; Got the translation, no use it!
	OR	A
	JR	Z,SOexit

	CP	9			; Is it TAB?
	JP	NZ,SO1
	CALL	JRTabExpand
	JP	SOexit
SO1	CALL	WriteBuffer		; Send character out
	CP	8			; Is it DEL?
	CALL	Z,JRDestDel
	CP	13			; Is it CR?
	CALL	Z,JRAddLF
SOexit	POP	HL			; Restore registers
	POP	AF
	RET

;----------------------------------------
;
;	REMOTE DESTRUCTIVE DELETE
;
;	This echos a 32 then an 8 to go
;	with the other 8, overwriting
;	the space
;	Entry - None
;	Exit  - None
; 	Used  - AF
;
;-----------------------------------------
JRDestDel
	DEFB	#C9			; Remote Destructive Delete 0 = on
RemoteDestDel
	LD	A,32
	CALL	WriteBuffer
	LD	A,8
	JP	WriteBuffer

;------------------------------------------
;
;	REMOTE ADD LF TO CR
;
;	This will add a LF to the previously
;	printed CR
;	Entry - None
;	Exit  - None
;	Used  - AF
;
;-------------------------------------------
JRAddLF
	DEFB	#C9			; Remote Add LF to CR 0 means on
RemoteAddLF
	LD	A,10
	JP	WriteBuffer

;--------------------------------------------
;
;	REMOTE TAB EXPANDER
;
;	This will expand a TAB to a string
;	of spaces TAB stops set at every 8
;	Entry - None
;	Exit  - None
;	Used  - AF
;
;---------------------------------------------
JRTabExpand
	BIT	0,(IY+2)
	JP	NZ,WriteBuffer
RemoteTabExpand
	PUSH	HL
	CALL	TXT_GET_CURSOR
	LD	A,H			; Put column in A
	CP	72			; Is it greater than last tab stop?
	JR	NC,rt4			; If so then replace it with a
					; CR
	DEC	A			; Convert from Logical to Physical
					; coordinates, ie left edge = 0
rt1	CP	8			; Is it less than 8
	JR	C,rt2
	SUB	A,8			; Reduce A by 8
	JP	rt1			; Go and check again
rt2	LD	B,A			; B = 8 - A
	LD	A,8
	SUB	B
	LD	B,A
	LD	A,32
rt3	CALL	WriteBuffer		; Then send the character
	DJNZ	rt3
	POP	HL			; Restore HL
	RET
rt4	LD	A,13			; Print a CR (with LF if on)
	CALL	SendOut
	POP	HL
	RET


	
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
;	LD	H,HighLocalBlock	; Put character through block mask
;	LD	L,A                     ; Will be zero if masked out
;	LD	A,(HL)
;	OR	A
;	JR	Z,PCexit		; If masked then exit now
; *** 22b - back to old translation tables  Seems better

	LD	H,HighLocalTrans	; Put through translation table
	LD	L,A
	LD	A,(HL)			; Now use the value!

	OR	A
	JP	Z,PCexit
;	Now dealt with in the screen output routine
;
;	CP	27			; Does it start an Ansi sequence?
;	JR	NZ,PrintC1
;	LD	A,#C9
;	LD	(JScrnBuf),A		; Screen buffer off
;	LD	(JScreenWrite),A	; Screen display off
;	XOR	A
;	LD	(JAnsi),A		; Ansi display on
;	JP	PCexit
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


