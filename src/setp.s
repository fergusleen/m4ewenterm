PRINT "BUFFERING/SETUP (SETP-22A)"
;----------------------------------------
;
;	BUFFER - USER SIDE
;
;	This routine reads from buffered
;	serial input
;	Entry - None
;	Exit  - A = Character
;		BC = No characters in buffer
;		     (before this one taken)
;		If no characters, A=0 BC=0
;	Used  - None
;
;----------------------------------------
ReadBuffer
	PUSH	HL			; Save registers
	PUSH	DE
	LD	HL,(Get_Buffer)		; Output pointer
	LD	DE,(Put_Buffer)		; Input pointer
	SCF
	CCF				; Clear carry
	PUSH	HL			; Save buffer address
	SBC	HL,DE
	LD	B,H
	LD	C,L			; Difference into HL
	POP	HL			; Retrieve buffer address
	LD	A,B			; How may characters in buffer?
	OR	C
	JR	Z,Exitit		; Exit - both zero, so no characters
					; in buffer
RB_DoIt
	PUSH	HL			; Save offset
	LD	DE,Buffer		; Start of buffer
	ADD	HL,DE			; Offset within buffer
	LD	A,(HL)			; Get DB into A
	POP	HL			; Retrieve offset
	PUSH	AF			; Temporary save character
	INC	HL			; Move Get pointer up
	LD	A,H
	CP	4
	JR	NZ,RB_Save
	LD	H,0
RB_Save
	LD	(Get_Buffer),HL		; And resave
	POP	AF			; And restore
	POP	DE
	POP	HL
	RET
Exitit	XOR	A			; Set A to zero to say not found
					; BC already equals zero
	POP	DE
	POP	HL			; Restore HL
	RET

;----------------------------------------
;
;	BUFFER - USER SIDE
;
;	This routine reads from buffered
;	serial input
;	Entry - A = Character
;	Exit  - C = 255 if buffer nearly full
;	Used  - None
;
;----------------------------------------
WriteBuffer
	PUSH	HL			; Save register
	PUSH	AF
	LD	A,(To_Buffer)		; Get buffer pointer
	LD	L,A			; Put in L
	POP	AF			; Get the character we are saving
	PUSH	AF			; And save it again
	LD	H,High_Buffer_Out	; High DB
	LD	(HL),A			; Save DB to buffer
	INC	L			; Next address
	LD	A,L
	LD	(To_Buffer),A		; Save buffer pointer
	LD	A,(From_Buffer)		; Get where from pointer
	LD	H,A			; From into H
	LD	A,L			; To into L
	SUB	H			; To - From
	CP	250			; Is it less than 250?
	JR	C,WBOkay
	LD	C,255			; Getting FULL!
	JR	WBexit
WBOkay	LD	C,0			; All is fine
WBexit	POP	AF
	POP	HL			; Restore all saved registers
	RET

;----------------------------------------
;
;	BUFFER NOT EMPTY
;
;	This routine tells the program
;	when the buffer is not empty
;
;	Entry - None
;	Exit  - Zero Flag =
;		  Z - Buffer empty
;		  NZ- Buffer not empty
;
;	Used  - F
;----------------------------------------
NotEmpty
	PUSH	HL			; Save registers
	PUSH	BC
	LD	B,A			; A into B for safe keeping
	LD	A,(From_Buffer)		; Output pointer
	LD	L,A
	LD	A,(To_Buffer)		; Input pointer
	CP	A,L			; Compare
	LD	A,B			; And restore them all
	POP	BC
	POP	HL
	RET

;----------------------------------------
;
;	BUFFER - SERIAL SIDE
;
;	This routine sends anything needing
;	sending, and recieves anything needing
;	to be recieved
;	Entry - None
;	Exit  - None
;	Used  - None
;
;----------------------------------------
SerialBuffer
; 	PUSH	AF			; Save ALL registers for later
; 	PUSH	BC
; 	PUSH	DE
; 	PUSH	HL
; ;	PUSH	IX
; ;	PUSH	IY
; WB2
; ;	CALL	SioStatus		; Get status
; ;	LD	BC,#FADD		; RS232 Channel A, control
; ;	LD	A,%00110000		; Error reset, register 0
; ;	OUT	(C),A			; Set up state
; ;	IN	A,(C)			; Read register (status)
; ;	BIT	0,A			; If there is something to get
; 	ld a,0
; 	JR	Z,Exit2			; else, onwards
; 	PUSH	AF			; Save status bit
; 	LD	HL,(Put_Buffer)		; Get buffer pointer
; 	PUSH	HL
; 	LD	DE,Buffer
; 	ADD	HL,DE
; ;	CALL	InChar			; then get it!
; 	;LD	BC,#FADC		; RS232 Channel A, data
; 	;IN	A,(C)		; Get data (which IS there)
; ;	call recv_noblock	; FL*******
; ;	Call start_rnd
; ; 	LD	(HL),A			; Save DB
; ; 	POP	HL
; ; 	INC	HL			; Next address
; ; 	LD	A,H
; ; 	CP	4
; ; 	JR	NZ,Sb_Save
; ; 	LD	H,0
; ; Sb_Save
; ; 	LD	(Put_Buffer),HL		; Save buffer pointer
; ; 	POP	AF			; Restore status bit
; Exit2	;BIT	2,A
; 	;JR	Z,Exit3			; If there is no space then skip this
; ; 	LD	A,(From_Buffer)		; Output pointer
; ; 	LD	L,A
; ; 	LD	A,(To_Buffer)		; Input pointer
; ; 	CP	A,L			; Compare
; ; 	JR	Z,Exit3			; Exit if nothing to send
; ; 	LD	H,High_Buffer_Out	; High DB
; ; 	LD	A,(HL)			; Get DB into A
; ; ;	CALL	OutChar			; send it out then
; ; 	LD	BC,#FADC		; RS232 Channel A, data
; ; 	OUT	(C),A			; send the data out
; ; 	INC	L			; Move Get pointer up
; ; 	LD	A,L
; ; 	LD	(From_Buffer),A		; And resave
; Exit3
; ;	POP	IY
; ;	POP	IX
; 	POP	HL			; Restore registers
; 	POP	DE
; 	POP	BC
; 	POP	AF
	RET				; Exit

;----------------------------------------
;
;	SETUP BUFFER
;
;	This routine sets up the buffering
;	needed to make things work
;	Entry - None
;	Exit  - None
;	Used  - AF,BC,DE,HL
;
;----------------------------------------
SetBuf	LD	HL,FastBlock		; Data block
	LD	DE,SerialBuffer		; Address to CALL
	LD	BC,#81FF		; Class/Rom State
	JP	KL_NEW_FAST_TICKER	; Enable, and return

;---------------------------------------
;
;	CLEAR BUFFER
;
;	This routine clears the buffer
;	Also turns off ticker interupt
;	Called remotely, only
;
;---------------------------------------
Clearbuffer
	XOR	A			; Clear slow response buffers
	LD	HL,0
	LD	(Get_Buffer),HL
	LD	(Put_Buffer),HL
	LD	(To_Buffer),A
	LD	(From_Buffer),A
	LD	HL,TickBlock		; Address of EVENT block
	CALL	KL_DISARM_EVENT		; Disable
	LD	HL,FastBlock		; Address of FAST TICKER block
	JP	KL_DEL_FAST_TICKER	; Remove, and exit

;----------------------------------------
;
;	SETUP
;
;	This routine is setups all the various
;	options
;	Called remotely
;
;----------------------------------------
Setup:	CALL	TXT_CUR_ON
	LD	HL,SetupMessage		; Print up signon message
	CALL	prints
	LD	HL,signon_message	; Print version and date
	CALL	Prints
;
;	LD	HL,WordWrapMessage	; Question
;	LD	DE,DPrintChar		; Patch address
;	LD	B,%11111011		; AND, if NO
;	LD	C,%00000100		; OR, if YES
;	LD	A,"N"			; Default
;	CALL	GetAnswer		; Now do it
;
	LD	HL,RemoteEchoMessage
	LD	DE,JRemoteEcho
	CALL	TwoState		; Sets up B,C, and A if two state
	CALL	GetAnswer
;
	LD	HL,LocalEchoMessage
	LD	DE,JLocalEcho
	CALL	TwoState
	CALL	GetAnswer
;
	LD	HL,LocalDestDelMessage
	LD	DE,JLDestDel
	CALL	TwoState
	CALL	GetAnswer
;
	LD	HL,LocalAddLFMessage
	LD	DE,JLAddLF
	CALL	TwoState
	CALL	GetAnswer
;
	LD	HL,LocalTabExpandMessage
	LD	DE,JLTabExpand
	CALL	TwoState
	CALL	GetAnswer
;
	LD	HL,RemoteDestDelMessage
	LD	DE,JRDestDel
	CALL	TwoState
	CALL	GetAnswer
;
	LD	HL,RemoteAddLFMessage
	LD	DE,JRAddLF
	CALL	TwoState
	CALL	GetAnswer
;
	LD	HL,RemoteTabExpandMessage
	LD	DE,DRemoteTabExpand
	CALL	TwoState
	CALL	GetAnswer
;
	JP	TXT_CUR_OFF		; Back to BASIC now

;---------------------------------------
;
;	TWO STATE SETUP
;
;	Sets up B # C # A if 255 and 0
;	are only values concerned
;	Entry - DE = address of patch
;	Exit  - B  = No value
;		C  = Yes value
;		A  = Default
;	Used  - None
;
;---------------------------------------
TwoState
	LD	B,#C9			; No
	LD	C,0			; Yes
	LD	A,(DE)			; Default
	OR	A
	JR	Z,TS_Yes		; Set to "Y"
	LD	A,"N"			; Set to "N"
	RET
TS_Yes	LD	A,"Y"
	RET

;---------------------------------------
;
;	GET ANSWER
;	
;	This routine gets the users answer
;	and processes it
;	Entry - HL = String to print
;		DE = Address to patch
;		B  = Value to AND with, No
;		C  = Value to OR with, Yes
;		A  = Default (Y/N)
;	Exit  - None
;	Used  - AF,BC,DE,HL
;
;---------------------------------------
GetAnswer
	PUSH	AF			; Save default
	CALL	Prints			; Print out the string
	POP	AF
	CALL	TXT_OUTPUT		; Print default
	PUSH	AF
	LD	A,8			; Back track
	CALL	TXT_OUTPUT
GA1	CALL	KM_WAIT_CHAR		; Get the character
	CP	"Y"			; Is it yes?
	JR	Z,GA_Yes
	CP	"y"
	JR	Z,GA_Yes
	CP	"N"			; Is it no?
	JR	Z,GA_No
	CP	"n"
	JR	Z,GA_No
	CP	13			; Is it return
	JR	Z,Ga_Leave
	CP	252			; Is it ESC?
	JR	Z,GA_Exit		; If so do something about it
	LD	A,7			; BEL
	CALL	TXT_OUTPUT
	JP	GA1			; Back to the top to try again
;
GA_Exit
	POP	AF			; Remove AF save
	POP	AF			; Remove return address for
					; this routine
	JP	TXT_CUR_OFF		; Exit same as above
	
;
GA_Yes	POP	AF			; Restore AF
	LD	HL,Yes			; Print yes message
	CALL	Prints
	LD	A,C			; Yes value
	LD	(DE),A			; Resave value
	RET				; Back to mainline

GA_No	POP	AF			; Restore AF
	LD	HL,No			; Print No message
	CALL	Prints
	LD	A,B			; No value
	LD	(DE),A			; Resave
	RET				; Back to mainline

GA_Leave
	POP	AF			; Restore default, and go to it
	PUSH	AF			; And save it again, for Yes/No
	CP	"Y"
	JR	Z,GA_Yes
	CP	"N"
	JR	Z,GA_No
	LD	A,13			; If not expected then down line
	CALL	TXT_OUTPUT		; and return
	LD	A,10
	CALL	TXT_OUTPUT
	RET

;
;	Terminal program JUMPBLOCK
;
;ToScreen
;	BIT	2,(IY)			; Word wrap first
;	CALL	NZ,WordWrap
;	OR	A
;	RET	Z
;	BIT	4,(IY)			; Capture buffer gets all
;	CALL	NZ,Capture
;	BIT	1,(IY)
;	CALL	NZ,Ansi			; Ansi Buffer if wanted there
;	OR	A
;	RET	Z
;	BIT	3,(IY)			; Screen buffer gets same as screen!
;	CALL	NZ,ScrnBuf
;	BIT	0,(IY)
;	RET	Z
;	JP	TXT_OUTPUT		; Screen if wanted there
;
; Keyboard
; 	BIT	0,(IY+1)
; 	JP	NZ,KM_READ_KEY
; 	BIT	1,(IY+1)
; 	JP	NZ,ExpndKey
; ;	BIT	2,(IY+1)
; ;	JP	NZ,FileKey
; 	RET
;
;	Dummy labels, things not written
Filekey


