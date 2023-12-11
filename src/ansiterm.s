print "ANSI EMULATION"
;----------------------------------------
;
;	ANSI EMULATION
;
;	Emulate the Ansi standard
;	NB Turned on when Chr
;	     27 recieved
;	Entry - A = Char
;	Exit  - None
;	Used  - None
;
;----------------------------------------
JAnsi  DB #C9  ; 0 = on, #C9 = off
Ansi	PUSH	HL
	PUSH	DE
	PUSH	BC
	PUSH	AF
	LD	C,A		; Move character into C for safe keeping
	CP	27
	JP	Z,AnsiMore	; If it is Chr 27 then we haven't just
				; been turned on, so don't bother with
				; all the checking
	LD	A,(CharacterNo)	; Character number in sequence
	OR	A		; Is this the first character?
	JP	Z,AnsiFirst	; Yes, deal with this strange occurance!

	LD	A,C		; Put character back in C to check

	CP	";"		; Is it a semi colon?
	JP	Z,AnsiSemi
	
	CP	"0"		; Is it a number?
	JR	C,Ansi_NN	; If <0 then no
	CP	"9"+1		; If >9 then no
	JP	C,AnsiNumber

Ansi_NN
	CP	"?"		; Simple trap for simple problem!
	JP	Z,AnsiMore

	CP	"@"		; Is it a letter?
	JP	C,AnsiExit	; Abandon if not letter; something wrong

AnsiFound
	LD	A,#C9
	LD	(JAnsi),A	; Turn itself off now
	XOR	A		; zero end of sequence marker

	LD	(JScreenWrite),A

	LD	HL,(NumberPos)	; Get value of number buffer
	LD	A,(HaveLoaded)	; Did we put anything in this byte?
	OR	A
	JR	NZ,AF1
	LD	(HL),255	; Mark the fact that nothing was put in
AF1	INC	HL
	LD	A,254
	LD	(HL),A		; Mark end of sequence (for unlimited length
				; sequences)
;*** Disable cursor, because it might well move!
	LD	A,(CursorOn)
	OR	A			; Well, what do we have here?!
	CALL	NZ,ToggleCursor		; If cursor on, then remove

	XOR	A
	LD	(CursorOn),A		; And cursor is now off
	LD	(CursorCount),A		; Restart count
	LD	A,#C9
	LD	(JChangeCursor),A	; Disable flashing temp

	LD	HL,NumberBuffer	; For the routine called
	LD	A,C		; Restore number
;
;	Now work out what happens
;
WHATISIT
	CP	"A"		; Check for supported Ansi characters
	JP	Z,CUU		; Upwards
	CP	"B"
	JP	Z,CUD		; Downwards
	CP	"C"
	JP	Z,CUF		; Forward
	CP	"D"
	JP	Z,CUB		; Backward
	CP	"H"
	JP	Z,CUP		; Locate
	CP	"f"
	JP	Z,HVP		; Locate
	CP	"J"
	JP	Z,ED		; Clear screen
	CP	"c"
	JP	Z,ED3		; RIS - fl Clear screen
	CP	"m"
	JP	Z,SGR		; Set graphics renditon
	CP	"K"
	JP	Z,EL		; Clear to end of line
	CP	"s"
	JP	Z,SCP		; Save the cursor position
	CP	"u"
	JP	Z,RCP		; Restore the cursor position

AnsiExit
	LD	HL,NumberBuffer	; Numbers buffer position
	LD	(NumberPos),HL
	XOR	A
	LD	(CharacterNo),A		; Next time it runs, it will be the
					; first character
	LD	(HaveLoaded),A		; We haven't filled this byte!
	LD	(JChangeCursor),A	; Cursor allowed back again!
AnsiMore
	POP	AF
	POP	BC
	POP	DE
	POP	HL
	RET

;
;	The various routines needed to handle the filtered characters
;
AnsiFirst
	LD	A,255
	LD	(CharacterNo),A		; Next character is not first!
	LD	A,C			; Get character back
	LD	(AnsiWasFirst),A	; Save first character to check later
	CP	"("			; ( and [ have characters to follow
	JP	Z,AnsiMore		; and are legal
	CP	"["
	JP	Z,AnsiMore
	CP	"c"
	JP	Z,AnsiFound		; Clear screen (RIS - FL)
	CP	#9B			; CSI
	JP	Z,AnsiF1		; Pretend that "[" was first ;-)
	LD	A,#C9
	LD	(JAnsi),A		; Turn itself off now
	XOR	A			; and turn the screen back on
	LD	(JScreenWrite),A
	JP	AnsiExit		; = and > don't have anything to follow
					; them but are legal  
					; Others are illegal, so abandon anyway
AnsiF1
	LD	A,"["			; Put a "[" for first character
	LD	(AnsiWasFirst),A
	JP	AnsiExit

AnsiSemi
	LD	HL,(NumberPos)		; Move the number pointer to the
	LD	A,(HaveLoaded)		; Did we put anything in this byte?
	OR	A
	JR	NZ,AS1
	LD	(HL),255		; Mark the fact that nothing was put in
AS1	INC	HL			; move to next byte
	LD	(NumberPos),HL
	XOR	A
	LD	(HaveLoaded),A		; New byte => not filled!
	JP	AnsiMore

AnsiNumber
	LD	HL,(NumberPos)		; Get address for number
	LD	A,(HaveLoaded)
	OR	A			; If value is zero
	JR	NZ,AN1
	LD	A,C			; Get value into A
	SUB	"0"			; Remove ASCII offset
	LD	(HL),A			; Save and Exit
	LD	A,255
	LD	(HaveLoaded),A		; Yes, we _have_ put something in!
	JP	AnsiMore

AN1
	LD	A,(HL)		; Stored value in A; TBA in C
	ADD	A		; 2 *
	LD	D,A		; Save the 2* for later
	ADD	A		; 4 *
	ADD	A		; 8 *
	ADD	D		; 10 *
	ADD	C		; 10 * + new num
	SUB	"0"		; And remove offset from C value!
	LD	(HL),A		; Save and Exit
	JP	AnsiMore
				; Note routine will only work up to 100
				; which should be okay for this application

;--------------------------------
;	GET NUMBER
;
;	Gets the next number from
;	the list
;
;	Entry - HL = address to get
;			from
;	Exit  - HL = next address
;		A  = value
;		IF a=255 then default value
;		If a=254 then end of sequence
;	Used  - None
;--------------------------------
GetNumber
	LD	A,(HL)		; Get number
	CP	254
	RET	Z		; Return if end of sequence,ie still point to
				; end
	INC	HL		; Return pointing to next byte
	RET			; Else next address and return

;***	ANSI UP
;
CUU	CALL	GetNumber		; Number into A
	LD	B,A			; Save value into B
	CP	255
	JR	NZ,CUUlp
	LD	B,1			; Default value
CUUlp	LD	A,(CursorPosition)	; A <- Row
	CP	A,B			; Is it too far?
	JR	C,CUU1
	SUB	B			; No, then go back that far
	LD	(CursorPosition),A	; Row <- A
	JP	AnsiExit
CUU1	LD	A,0			; Make the choice, top line
	LD	(CursorPosition),A	; Row <- A
	JP	AnsiExit

;***	ANSI DOWN
;
CUD	LD	A,(AnsiWasFirst)
	CP	"["
	JP	NZ,AnsiExit		; Ignore ESC(B
	CALL	GetNumber
	LD	B,A			; Save value in b
	CP	255
	JR	NZ,CUDlp
	LD	B,1			; Default
CUDlp	LD	A,(CursorPosition)	; A <- Row
	ADD	A,B
	CP	screen_depth		; Too far?
	JP	C,CUD1
	LD	A,screen_depth-1	; Too far then bottom of screen
CUD1	LD	(CursorPosition),A	; Row <- A
	JP	AnsiExit

;***	ANSI RIGHT
;
CUF	CALL	GetNumber		; Number into A
	LD	B,A			; Value saved in B
	CP	255
	JR	NZ,CUFget
	LD	B,1			; Default
CUFget	LD	A,(CursorPosition+1)	; A <- Column
	ADD	B			; Add movement
	CP	80			; Too far?
	JR	C,CUF2
	LD	A,79			; Yes, right edge
CUF2	LD	(CursorPosition+1),A	; Column <- A
	JP	AnsiExit

;***	ANSI LEFT
;
CUB	CALL	GetNumber		; Number into A
	LD	B,A			; Save value in B
	CP	255
	JR	NZ,CUBget
	LD	B,1			; Default
CUBget	LD	A,(CursorPosition+1)	; A <- Column
	CP	A,B			; Too far?
	JR	C,CUB1a
	SUB	A,B
	LD	(CursorPosition+1),A	; Column <-A
	JP	AnsiExit
CUB1a	LD	A,0
	LD	(CursorPosition+1),A	; Column <-A
	JP	AnsiExit

;***	ANSI LOCATE
;
HVP
CUP	CALL	GetNumber
	CP	255
	CALL	Z,DefaultLine	; Default = 1
	CP	254		; Sequence End -> 1
	CALL	Z,DefaultLine
	CP	screen_depth+1	; Out of range then don't move
	JP	NC,AnsiExit
	OR	A
	CALL	Z,DefaultLine	; 0 means default, some strange reason
	LD	E,A
	CALL	GetNumber
	CP	255		; Default = 1
	CALL	Z,DefaultColumn
	CP	254		; Sequence End -> 1
	CALL	Z,DefaultColumn
	CP	81		; Out of range, then don't move
	JP	NC,AnsiExit
	OR	A
	CALL	Z,DefaultColumn	; 0 means go with default
	LD	D,A
	EX	HL,DE
	DEC	H		; Translate from Ansi co-ordinates to hardware
	DEC	L		; co-ordinates
	LD	(CursorPosition),HL	; Set the cursor position
	JP	AnsiExit

DefaultColumn
DefaultLine
	LD	A,1
	RET

;***	ANSI CLEAR SCREEN
;
ED	CALL	GetNumber
	OR	A
	JP	Z,ED1		; Zero means first option
	CP	254		; Also default
	JP	Z,ED1
	CP	255
	JP	Z,ED1
	CP	1
	JP	Z,ED2
	CP	2
	JP	NZ,AnsiExit
;***	Option 2
;
ED3	LD	HL,0
	LD	(CursorPosition),HL	; Home the cursor
	LD	(ScreenOffset),HL
	CALL	SCR_SET_OFFSET		; Tell the hardware about it
	LD	A,(JSW_FF)
	OR	A
	JP	NZ,ED_Set_LF

	; comment this out as the shutter effect is nice!

	; XOR	A			; Save inks
	; CALL	SCR_GET_INK
	
	; LD	(Ink0),BC

	; LD	A,1
	; CALL	SCR_GET_INK

	; LD	(Ink1),BC

	; XOR	A			; Blank the inks
	; LD	B,A
	; LD	C,A
	; CALL	SCR_SET_INK
	
	; LD	A,1
	; LD	B,0
	; LD	C,B
	; CALL	SCR_SET_INK

	CALL	MC_WAIT_FLYBACK


	call romdis
	LD	HL,#C000		; From
	LD	DE,#C001		; To
	LD	BC,16383		; Screen length
	LD	(HL),0
	LDIR
	call romen

	; XOR	A
	; LD	BC,(ink0)
	; CALL	SCR_SET_INK

	; LD	A,1
	; LD	BC,(ink1)
	; CALL	SCR_SET_INK
	LD	A,#C9			; Prevent clear screen
	LD	(JSW_FF),A		; until something written

	JP	AnsiExit

ED_Set_LF
	XOR	A			; Note simply so that
	LD	(JSW_LF),A		; ESC[2J works the same as CTRL-L
	CAll JSW_LF
	JP	AnsiExit

;***	Option 0
;
ED1	
	LD	HL,(CursorPosition)	; Get and save cursor position
	LD	A,H
	OR	L
	JP	Z,ED3			; If we are at the top of the
					; screen and clearing to the bottom
					; then we are clearing all the screen!

	PUSH	HL
	
	LD	A,screen_depth-1
	SUB	L			; screen_depth - Row

	LD	HL,0			; Zero start

	OR	A			; Do we have any lines to add?
	JR	Z,ED1_2			; If no bypass that addition!

	LD	B,A			; Number of lines to count
	LD	DE,80
ED1_1
	ADD	HL,DE
	DJNZ	ED1_1
	
ED1_2
	EX	HL,DE			; Value into DE
	POP	HL
	LD	A,80
	SUB	H			; 80 - Columns
	LD	L,A			; Add to value before
	LD	H,0
	ADD	HL,DE

	PUSH	HL			; Value saved for later
	call romdis
	LD	HL,(CursorPosition)	; _that_ value again!

	CALL	FindCursor		; So where does it all begin?

	POP	BC			; Number to blank
        PUSH	BC			; Save for a moment!

	CALL	ScreenBlank		; Now do it!
	call romen
	
	POP	BC
	;CALL	BufferBlank
	JP	AnsiExit		; Then exit properly

;***	Option	1
;
ED2

	LD	HL,(CursorPosition)	; Get and save cursor position
	PUSH	HL
	
	LD	A,L
	
	LD	HL,0			; Zero start

	OR	A			; Do we have any lines to add?
	JR	Z,ED2_2			; If no bypass that addition!

	LD	B,A			; Number of lines
	LD	DE,80
ED2_1
	ADD	HL,DE
	DJNZ	ED2_1
	
ED2_2
	EX	HL,DE			; Value into DE
	POP	HL
	LD	L,H			; Add to value before
	LD	H,0
	ADD	HL,DE

	PUSH	HL			; Value saved for later

	LD	HL,0			; Find the begining!
	call romdis
	CALL	FindCursor		; So where does it all begin?
	
	POP	BC			; Number to blank
	PUSH	BC			; Save for a while

	CALL	ScreenBlank		; Now do it!
	call romen
	LD	HL,0			; Find start position
	POP	BC

	JP	AnsiExit		; Then exit properly

; ***	ANSI CLEAR LINE
;
EL	CALL	GetNumber		; Get value
	CP	0
	JP	Z,EL1		; Zero # Default are the same
	CP	255
	JP	Z,EL1
	CP	254
	JP	Z,EL1
	CP	1
	JP	Z,EL2
	CP	2
	JP	NZ,AnsiExit	; Otherwise don't do a thing
;***	Option 2
;
	LD	HL,(CursorPosition)
	LD	H,0
	PUSH	HL
	call romdis
	CALL	FindCursor		; Start of line position
	
	LD	BC,80			; 80 bytes to clear (whole line)
	
	CALL	ScreenBlank
	call romen
	POP	HL

	JP	AnsiExit

;***	Option 0
;
EL1	LD	HL,(CursorPosition)
	LD	A,80		; Calculate distance to end of line
	SUB	H
	LD	C,A
	LD	B,0
	PUSH	BC
	PUSH	HL
	PUSH	BC
	call romdis
	CALL	FindCursor	; Find current position
	POP	BC
	CALL	ScreenBlank
	call romen
	POP	HL
	POP	BC
	JP	AnsiExit

;***	Option 1
;
EL2	LD	HL,(CursorPosition)
	LD	C,H		; BC = distance from start of line
	LD	B,0
	LD	H,0
	PUSH	BC
	PUSH	HL
	PUSH	BC
	call romdis
	CALL	FindCursor	; Find start of line

	POP	BC
	CALL	ScreenBlank
	call romen
	POP	HL
	POP	BC


	JP	AnsiExit

ScreenBlank
;
;	HL = address to clear from
;	BC = number of bytes to clear
; Uses/Abuses - Most registers
;

	LD	D,8			; Value to add between lines
ScreenBlank_Next
	LD	E,8			; 8 bytes down
	PUSH	HL
ScreenBlank_Down
	LD	A,(JInverse)		; Flag for inverse on
	OR	A
	JR	Z,SBD1
	XOR	A			; If off, then fill with zeros
	JR	Z,SBD2
SBD1
	CPL				; If on (0), load with 255's
SBD2	
	LD	(HL),A			; Loop downwards
	LD	A,H			; Add offset
	ADD	D
	LD	H,A
	DEC	E			; 1 less line to go
	LD	A,E
	OR	A			; Are there any lines left?
	JR	NZ,ScreenBlank_Down
	POP	HL
	CALL	ScreenBlank_Across
	DEC	BC			; 1 less across now!
	LD	A,C
	OR	B
	JR	NZ,ScreenBlank_Next

	RET

ScreenBlank_Across
	INC	HL			; HL = HL + 1
	LD	A,H
	AND	%00000111		; Mask back into range of screen
	ADD	A,#C0			; Add base of screen address
	LD	H,A

	RET



;***	ANSI SET GRAPHICS RENDITION
;
SGR	CALL	GetNumber
	CP	254		; 254 signifies end of sequence
	JP	Z,AnsiExit
	OR	A
	CALL	Z,AllOff
	CP	255		; Default means all off
	CALL	Z,AllOff
	CP	1
	CALL	Z,BoldOn
	CP	2
	CALL	Z,BoldOff
	CP	4
	CALL	Z,UnderOn
	CP	5
	CALL	Z,ItalicOn
	CP	6
	CALL	Z,ItalicOn
	CP	7
	CALL	Z,InverseOn
	CP	8
	CALL	Z,Samebackfore
	CP	29		; 30 to 37 are foreground colours
	CALL	NC,Back_Fore
	JP	SGR		; Code is re-entrant

;--------------------------------
;
;	RESET GRAPHICS
;
;	Entry - None
;	Exit  - None
;	Used  - None
;--------------------------------
AllOff:
	PUSH	AF		; Save registers
	LD	A,#C9		; = off
	LD	(JBold),A	; Turn the flags off
	LD	(JItalics),A
	LD	(JUnder),A
	LD	(JInverse),A
	LD	(JSmash),A
	LD	(JHighInt),A
	XOR	A		; Reset background to black
	LD	(backcolour),A
	LD	A,7		; Reset foreground to white
	LD	(forecolour),A
	XOR	A
	LD	(fontset),A	; Reset the bit map store
	POP	AF		; Restore register
	RET

;--------------------------------
;
;	TURN BOLD ON
;
;	Entry - None
;	Exit  - None
;	Used  - None
;--------------------------------
BoldOn	PUSH	AF		; Save register
	XOR	A		; 0 means on
	LD	(JBold),A
	LD	(JHighInt),A
	LD	A,(forecolour)	; And update the foreground colour,
	CP	8		; (if less than 8)
	JR	NC,BOn1
	OR	A		; so long as it is not 0
	JR	Z,BOn1
	ADD	8
	LD	(forecolour),A
	LD	A,#C9		; If bold is on, then it only affects fore
	LD	(JSmash),A	; So we MUST NOT clear the character
BOn1
	LD	A,(fontset)
	SET	0,A		; turn ON indicator flag
	LD	(fontset),A
	POP	AF		; Restore register
	RET

;--------------------------------
;
;	TURN BOLD OFF
;
;	Entry - None
;	Exit  - None
;	Used  - None
;--------------------------------
BoldOff
	PUSH	AF		; Save register
	PUSH	BC
	LD	A,#C9		; #C9 means off
	LD	(JBold),A
	LD	(JHighInt),A
	LD	A,(forecolour)	; And update the foreground colour
	CP	8		; so long as it is above 8
	JR	C,BO1
	SUB	8
	LD	(forecolour),A
	LD	C,A
	LD	A,(backcolour)
	LD	B,A
	LD	A,C
	CALL	SmashThem	; Do we now clear the colour?
BO1
	LD	A,(fontset)
	RES	0,A		; turn OFF indicator flag
	LD	(fontset),A
	POP	BC
	POP	AF		; Restore register
	RET

;--------------------------------
;
;	TURN ITALICS ON
;	(replaces flashing)
;	Entry - None
;	Exit  - None
;	Used  - None
;--------------------------------
ItalicOn
	PUSH	AF		; Save AF
	XOR	A
	LD	(JItalics),A	; 0 means on
	LD	A,(fontset)
	SET	1,A		; turn ON indicator flag
	LD	(fontset),A
	POP	AF		; Restore register
	RET

;--------------------------------
;
;	TURN UNDERLINE ON
;
;	Entry - None
;	Exit  - None
;	Used  - None
;--------------------------------
UnderOn
	PUSH	AF		; Save register
	XOR	A		; 0 means on
	LD	(JUnder),A
	LD	A,(fontset)
	SET	2,A		; turn ON indicator flag
	LD	(fontset),A
	POP	AF		; Restore register
	RET

;--------------------------------
;
;	TURN INVERSE ON
;
;	Entry - None
;	Exit  - None
;	Used  - None
;--------------------------------
InverseOn
	PUSH	AF		; Save register
	XOR	A		; 0 means on
	LD	(JInverse),A
	LD	A,(backcolour)	; Save back colour
	PUSH	AF
	LD	A,(forecolour)	; Copy fore colour into back colour
	LD	(backcolour),A
	POP	AF		; Retrieve back colour, and copy into 
	LD	(forecolour),A	; fore colour
	LD	A,(fontset)
	SET	3,A		; turn ON indicator flag
	LD	(fontset),A
	POP	AF		; Restore AF
	RET

;--------------------------------
;
;	SET FOREGROUND COLOUR
;		TO BACKGROUND
;
;	Entry - None
;	Exit  - None
;	Used  - None
;	
;--------------------------------
Samebackfore
	PUSH	AF
	LD	A,(backcolour)	; Get background colour
	LD	(forecolour),A	; Save into foreground colour
	XOR	A
	LD	(JSmash),A	; Turn Smash! on
	LD	A,(fontset)
	SET	4,A		; turn ON indicator flag
	LD	(fontset),A
	POP	AF
	RET

;--------------------------------
;
;	BACK/FORE GROUND
;
;	Entry - A = >39 for fore
;		    >29 for back
;	Exit  - None
;	Used  - None
;
;--------------------------------
Back_Fore
	CP	39
	JR	NC,BackGround
;	otherwise drop through to foreground colour

;--------------------------------
;
;	SET FOREGROUND COLOUR
;	
;	Entry - None
;	Exit  - None
;	Used  - None
;
;--------------------------------
foreground
	PUSH	AF
	PUSH	BC
	SUB	30		; Bring down to 0 base
	OR	A		; If not zero then
	CALL	NZ,JHighInt	; Add 8 if high intensity
	LD	(forecolour),A	; Save colour
	LD	C,A
	LD	A,(backcolour)	; get the other one
	LD	B,A		; B = background
	LD	A,C		; A = foreground
	CALL	SmashThem	; Toggle smash?
;	CP	A,B		; are they the same?
;	JR	Z,fg1
;	LD	A,#C9		; RET
;	LD	(JSmash),A	; turn off smash!
;	POP	BC
;	POP	AF
;	RET
;fg1
;	XOR	A
;	LD	(JSmash),A	; turn smash! on
	POP	BC
	POP	AF
	RET

;--------------------------------
;
;	SET BACKGROUND COLOUR
;	
;	Entry - None
;	Exit  - None
;	Used  - None
;
;--------------------------------
background
	PUSH	AF
	PUSH	BC
	SUB	40		; Bring down to 0 base
;	CALL	JHighInt	; Add 8 if high intensity
				;  -- NOT BACKGROUND --??????
	LD	(backcolour),A	; Save colour
	LD	B,A
	LD	A,(forecolour)	; get the other one
	CALL	SmashThem	; Turn smash on?
;	CP	A,B		; are they the same?
;	JR	Z,bg1
;	LD	A,#C9		; RET
;	LD	(JSmash),A	; turn off smash!
;	POP	BC
;	POP	AF
;	RET
;bg1
;	XOR	A
;	LD	(JSmash),A	; turn smash! on
	POP	BC
	POP	AF
	RET

;-------------------------------
;
;	SMASH ON/OFF
;
;	Entry - A/B = fore/back
;	Exit  - Smash on if same
;		Underline on if 4
;	Used  - AF
;
;-------------------------------
SmashThem
	PUSH	AF
	CP	A,B		; are they the same?
	JR	Z,STB1
	LD	A,#C9		; RET
	LD	(JSmash),A	; turn off smash!
	LD	A,(fontset)
	RES	4,A		; turn OFF indicator flag
	LD	(fontset),A
	POP	AF
	AND	7		; Mask out high intensity flag
	OR	A		; Is A zero?
	JR	NZ,ST1
	LD	(JInverse),A	; Inverse ON, if 0
	LD	A,(fontset)
	SET	3,A		; turn ON indicator flag
	LD	(fontset),A
;	LD	A,#C9		; If it is 0 then it cannot be 4!!
;	LD	(JUnder),A	; Underline off
	RET
ST1
;	PUSH	AF
	LD	A,#C9		; Turn inverse off if not 0
	LD	(JInverse),A
	LD	A,(fontset)
	RES	3,A		; turn OFF indicator flag
	LD	(fontset),A
;	POP	AF
;	CP	4		; Is it 4?
;	JR	NZ,ST2
;	XOR	A		; If so, turn underline on
;	LD	(JUnder),A
;	RET
ST2
;	LD	A,#C9		; Otherwise turn it off
;	LD	(JUnder),A
	RET

STB1	XOR	A		; NOP
	LD	(JSmash),A	; turn smash! on
	LD	A,(fontset)
	SET	4,A		; turn ON indicator flag
	LD	(fontset),A
	POP	AF
	RET

;-------------------------------
;
;	SET HIGH INTENSITY
;
;	Entry - A = Colour
;	Exit  - A = Colour or
;		A = High Intensity Colour
;	Used  - None
;
;-------------------------------
JHighInt
	DB	#C9		; 0 means on, #C9 means off
HighInt
	ADD	8
	RET

;***	ANSI SAVE CURSOR POSITION
;
SCP	LD	HL,(CursorPosition)	; (backup) <- (current)
	LD	(Cursor_Pos),HL
	JP	AnsiExit

;***	ANSI RESTORE CURSOR POSITION
;
RCP	LD	HL,(Cursor_Pos)		; (current) <- (backup)
	LD	(CursorPosition),HL
	JP	AnsiExit
