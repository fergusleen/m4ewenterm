print	"SCREEN EMULATION"
;------------------------------------
;
;	TO SCREEN
;
;	This routine sends the outputed
;	character to all the relevant
;	places
;
;	Entry - A = Character
;	Exit  - None
;	Used  - AF
;
;------------------------------------
ToScreen:
	CALL	JScreenWrite	; THE screen, and buffer
	CALL	JAnsi			; Ansi emulator (not on when screen is)
	RET

;------------------------------------
;
;	SCREEN WRITE
;
;	This routine modifies the
;	character to the Ansi
;	graphic type set, and then
;	sends it to the screen
;
;	Entry - A = Charcter
;	Exit  - A = Character
;	Used  - None
;
;------------------------------------
JScreenWrite DB	0 ;0			; Set to #C9 if screen not being

ScreenWrite
	PUSH	HL
	PUSH	DE
	PUSH	BC
	PUSH	AF			; Save registers
	LD	D,A			; Temp save for A
	
	LD	A,(CursorOn)
	OR	A			; Well, what do we have here?!
	CALL	NZ,ToggleCursor		; If cursor on, then remove

	XOR	A
	LD	(CursorOn),A		; And cursor is now off
	LD	(CursorCount),A		; Restart count
	LD	A,#C9
	LD	(JChangeCursor),A	; Disable flashing temp
	
	LD	A,D			; Restore value of A

	CP	31			; Is it a control character?
	JP	NC,SW1
	CP	7			; Is it a control character used?
	JP	Z,SW_Bell
	CP	8
	JP	Z,SW_BS
	CP	9
	JP	Z,SW_TAB
	CP	10
	JP	Z,SW_LF
	CP	12
	JP	Z,SW_FF
	CP	13
	JP	Z,SW_CR
	CP	27			; Is it the ESC character, starting
					; an ANSI sequence?
	JP	Z,SW_Ansi
					; If so, make the screen act on it
					; otherwise print it out
	CP	#9B
	JP	Z,SW_Ansi		; Also, an Ansi switch on  
					; Ansi handler does the rest
SW1	
	LD	HL,Character		; Character buffer address
	CALL	Getcharacter
	CALL	JItalics		; Set the character matrix up
	CALL	JBold
	CALL	JUnder
	CALL	JInverse

	CALL	JSmash

	call ROMDIS
	EX	HL,DE
	LD	HL,(CursorPosition)
	PUSH	HL			; Save cursor position for later
	
	; Write Character to Cursor Position.

	CALL	FindCursor		; Now HL = screen memory address
					;     DE = character data address
	LD	B,8			; Value to add between lines(high only)
	LD	A,(DE)			; From buffer
	LD	(HL),A			; To screen
	LD	A,H			; To next block
	ADD	B
	LD	H,A
	INC	E			; To next DB

	LD	A,(DE)			; 2
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A
	INC	E			; NB Must not be split across page

	LD	A,(DE)			; 3
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A
	INC	E

	LD	A,(DE)			; 4
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A
	INC	E

	LD	A,(DE)			; 5
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A
	INC	E

	LD	A,(DE)			; 6
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A
	INC	E
	
	LD	A,(DE)			; 7
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A
	INC	E

	LD	A,(DE)			; 8
	LD	(HL),A
	call romen

	POP	HL			; Restore cursor position
	LD	A,H
	CP	79			; Are we at the right edge?
	JR	NZ,SW1_5		; If yes
	LD	H,0			; Column zero now
	
	
	CALL	SW_LFn			; Move down the line (don't load)

	LD	A,#C9
	LD	(JSW_LF),A		; Turn off line feed for next
					; character
	JP	SWR_None		; _don't_ re-enable LF and there
					; is no need to re-enable FF either

SW1_5	INC	H			; One more across
	LD	(CursorPosition),HL

SW_Restore				; Restore all values, and then return
	XOR	A
	LD	(JSW_LF),A		; Turn LF back on
	LD	(JSW_FF),A		; Turn FF back on
SWR_None
	XOR	A			; Cursor int back on
	LD	(JChangeCursor),A
	POP	AF
	POP	BC
	POP	DE
	POP	HL
	RET

SWR_FF	XOR	A
	LD	(JSW_FF),A		; Turn FF back on
	LD	(JChangeCursor),A	; And cursor may flash now
	POP	AF			; Then registers
	POP	BC
	POP	DE
	POP	HL
	RET

SWR_LF	XOR	A
	LD	(JSW_LF),A		; Turn LF back on
	LD	(JChangeCursor),A	; And cursor may flash now
	POP	AF			; and registers
	POP	BC
	POP	DE
	POP	HL
	RET

SW_Bell				; Sound the bell
	CALL	TXT_OUTPUT		; Force firmware to handle this!
	JP	SWR_None		; And that was it!

SW_BS
	LD	A,(CursorPosition+1)	; A = column
	OR	A			; Is zero?
	JP	Z,SWR_None		; Don't wrap back
	DEC	A			; Back one column
	LD	(CursorPosition+1),A	; Resave cursor position
	JP	SWR_None		; That's it folks!

SW_TAB
	LD	A,(CursorPosition+1)	; A = column
	AND	%11111000		; Mult of 8
	CP	72			; If at 72, then we CR/LF not TAB!!
	JR	NZ,SW_Tab1
	XOR	A
	LD	(CursorPosition+1),A	; Do the CR
	JP	SW_LF_All		; _must_ do it, so no messing with
					; jumpblocks
SW_Tab1	
	ADD	A,8			; Next stop
	LD	(CursorPosition+1),A	; And save
	JP	SWR_None		; And that was that!
	
SW_LF	LD	A,(JSW_LF)
	OR	A
	CALL	Z,SW_LF_All
	JP	SWR_LF			; We have just avoided it, or done it
					; either way allow it now
SW_LF_All
	LD	HL,(CursorPosition)	; Do we need to scroll?
SW_LFn	INC	L			; Next line
	LD	A,L			; Now, put it into A so we can do
					; things with it!
	CP	screen_depth		; Have we gone past the end?
	JR	Z,SWLF1			; Must scroll
	LD	(CursorPosition),HL	; Save new position
	RET

SWLF1					; Now the hard bit
	DEC	L			; Back to line 24
	LD	(CursorPosition),HL	; Resave cursor position

;*** Scroll the screen up

	LD	HL,(ScreenOffset)	; Get current offset
	LD	DE,80			; Offset to add
	ADD	HL,DE			; Addit!
	LD	A,H
	AND	%00000111		; Mask back into range
	LD	H,A
	
	LD	(ScreenOffset),HL
	CALL	SCR_SET_OFFSET		; Tell the hardware about it

	LD	B,255			; Scroll upwards
	XOR	A			; Fill with 0's. FL- This is the paper.
	CALL	SCR_HW_ROLL		; Move the screen up and blank the bottom line
	CALL SW_LF_Across
	RET				; That's all here

SW_LF_Across
	INC	HL			; HL = HL + 1
	LD	A,H
	AND	%00000111		; Mask back into range of screen
	ADD	A,#C0			; Add base of screen address
	LD	H,A
	RET



SW_FF					; Clear the screen
	LD	HL,0
	LD	(CursorPosition),HL	; Home the cursor

	LD	A,(JSW_FF)
	OR	A
	JP	NZ,SWR_LF

	XOR	A			; Save inks
	CALL	SCR_GET_INK
	
	LD	(Ink0),BC

	LD	A,1
	CALL	SCR_GET_INK

	LD	(Ink1),BC

	XOR	A			; Blank the inks
	LD	B,A
	LD	C,A
	CALL	SCR_SET_INK
	
	LD	A,1
	LD	B,0
	LD	C,B
	CALL	SCR_SET_INK

	CALL	MC_WAIT_FLYBACK

	call romdis

	LD	HL,#C000		; From
	LD	DE,#C001		; To
	LD	BC,16383		; Screen length
	LD	(HL),0
	LDIR

	call romen

	XOR	A
	LD	BC,(ink0)
	CALL	SCR_SET_INK

	LD	A,1
	LD	BC,(ink1)
	CALL	SCR_SET_INK

	LD	A,#C9			; Prevent clear screen
	LD	(JSW_FF),A		; until something written

	; LD	A,(JScrnBuf)		; Is the buffer on?
	; LD	(SW_FF_JBuf),A
	; CALL	SW_FF_JBuf
	
	JP	SWR_LF


SW_CR
	LD	HL,(CursorPosition)	; Get cursor pos
	LD	H,0			; Zero column
	LD	(CursorPosition),HL	; Save cursor pos
	JP	SWR_None		; Say your prayers

SW_Ansi
	LD	A,#C9
	LD	(JScreenWrite),A	; Screen display off
	XOR	A
	LD	(JAnsi),A		; Ansi display on
	JP	SWR_None

;---------------------------------------
;
;	TOGGLE CURSOR
;
;	This routine turns the cursor
;	off, or turns it on depending
;	on its current state
;
;	Entry - None
;	Exit  - None
; 	Used  - AF,BC,HL
;
;---------------------------------------
ToggleCursor

	CALL ROMDIS

	LD	HL,(CursorPosition)	; Get position on screen
	CALL	FindCursor		; Find out where we are!
	LD	B,8			; Value to add between lines

	LD	A,(HL)			; From Screen
	CPL				; 1's to 0's, and vice versa
	LD	(HL),A			; To screen
	LD	A,H			; Move to next block
	ADD	B
	LD	H,A

	LD	A,(HL)			; 2
	CPL
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A

	LD	A,(HL)			; 3
	CPL
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A

	LD	A,(HL)			; 4
	CPL
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A

        LD	A,(HL)			; 5
	CPL
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A

	LD	A,(HL)                   ; 6
	CPL			
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A
	
	LD	A,(HL)			; 7
	CPL
	LD	(HL),A
	LD	A,H
	ADD	B
	LD	H,A

	LD	A,(HL)			; 8
	CPL
	LD	(HL),A
	
	CALL ROMEN

	RET				; Back to life

;---------------------------------------
;	SET CURSOR FLASHING INT ON
;
;	Turns on a SCR FLYBACK event
;	which will flash cursor
;
;	Entry - None
;	Exit  - None
;	Used  - AF,BC,DE,HL
;
;---------------------------------------
SetCursorInterupt
	LD	HL,CursorBlock		; Frame Fly Event block
	LD	DE,ChangeCursor		; Routine to call
	LD	BC,#81FF		; Async event, Near address
					; Disable roms
	CALL	KL_NEW_FRAME_FLY	; Initialise it
	CALL	ToggleCursor
	LD	A,255
	LD	(CursorOn),A		; Tell routine cursor is on screen
	XOR	A
	LD	(JChangeCursor),A	; Tell routine that cursor is allowed
					; flash
	LD	(CursorCount),A		; Count for flash frequencey
	RET

;---------------------------------------
;	TURN CURSOR FLASHING OFF
;
;	Turns off SCR_FLYBACK event
;	and removes cursor
;
;	Entry - None
;	Exit  - None
;	Used  - AF,BC,DE,HL
;
;---------------------------------------
OffCursorInterupt
	DI
	LD	HL,CursorBlock+2	; Address of event block
	CALL	KL_DISARM_EVENT		; Disable the event
	LD	HL,CursorBlock		; Address of frame fly block
	CALL	KL_DEL_FRAME_FLY	; And disable it
	DI				; Just incase it was about to do
					; naughty things!
	LD	A,(CursorOn)
	OR	A
	CALL	NZ,ToggleCursor		; Remove if on screen
	XOR	A
	LD	(CursorOn),A		; Tell routine cursor is off
	LD	A,#C9
	LD	(JChangeCursor),A	; and _must_not_ flash
	EI
	RET

;---------------------------------------
;	CHANGE CURSOR STATE
;
;	Called in interupt line
;
;	Entry - None
;	Exit  - None
;	Used  - None
;
;---------------------------------------
; *** A couple of equates for fast changes first
C_Time_Off	EQU	10
C_Time_On	EQU	30
; *** Now the actual code
ChangeCursor
JChangeCursor
	DB	0			; #c9 to disable, 0 to enable
	PUSH	AF
	LD	A,(CursorOn)		; Is the cursor on (for timings)?
	OR	A
	JR	NZ,CC_On
;*** Cursor is Off
	LD	A,(CursorCount)		; Counter
	CP	C_Time_Off		; Have we been off long enough
	JR	Z,CC_Turn_On		; If yes, then do the work
	INC	A
	LD	(CursorCount),A		; Otherwise increase and save
CC_NoChange
	POP	AF
	RET				; Restore registers, and continue

CC_Turn_On
	PUSH	BC
	PUSH	DE
	PUSH	HL
	XOR	A
	LD	(CursorCount),A		; Restart count, for off
	LD	A,255
	LD	(CursorOn),A		; Make note that cursor is now on
	CALL	ToggleCursor		; Do the actual work
	POP	HL
	POP	DE
	POP	BC
	POP	AF
	RET

CC_On
	LD	A,(CursorCount)		; Counter
	CP	C_Time_On		; Have we been on long enough?
	JR	Z,CC_Turn_Off		; If yes, then do the toggle
	INC	A
	LD	(CursorCount),A		; Otherwise increase and save
	POP	AF
	RET

CC_Turn_Off	
	PUSH	BC
	PUSH	DE
	PUSH	HL
	XOR	A
	LD	(CursorCount),A		; Restart count, for off
	LD	(CursorOn),A		; Make note that cursor is now off
	CALL	ToggleCursor		; Do the actual work
	POP	HL
	POP	DE
	POP	BC
	POP	AF
	RET

;---------------------------------------
;
;	FIND SCREEN DB
;
;	Finds appropriate Byte in screen
;	memory for cursor position
;
;	Entry - HL = Cursor position
;	Exit  - HL = DB in screen
;	Used  - None
;
;---------------------------------------
FindCursor
	PUSH	AF
	PUSH	DE
	PUSH	HL

	LD	A,L			; Get row in A
	ADD	L			; double row number
	LD	L,A			; Get low DB into L

	LD	H,HighScreenAddress	; Get high DB into H
	LD	E,(HL)			; Get into DE
	INC	HL
	LD	D,(HL)
	POP	HL
	LD	L,H			; Prepare value to add
	LD	H,0
	ADD	HL,DE			; Offset now in HL
	EX	HL,DE			; Save value into DE
	LD	HL,(ScreenOffset)	; Get offset from start
	ADD	HL,DE			; Add that in too
	LD	A,H
	AND	%00000111		; Mask into 2K region
	ADD	A,#C0			; Bring back into range
	LD	H,A
	POP	DE
	POP	AF
	RET

;------------------------------------
;
;	GET CHARACTER
;
;	Entry - HL = address to put
;		A  = character
;	Exit  - None
;	Used  - DE
;
;------------------------------------
GetCharacter
	PUSH	HL
	LD	E,A
	LD	D,HCharSet
	LD	B,8
GC1	LD	A,(DE)
	LD	(HL),A
        INC	D
	INC	HL
	DJNZ	GC1
	POP	HL
	RET

;------------------------------------
;
;	SCREEN ATRIBUTES
;
;	These routines configure
;	the character suitably!
;	Entry - HL = Address of character
;	Exit  - None
;	Used  - AF,BC,DE
;------------------------------------
JBold	DB	#C9			; 0 = On, #C9 = off
Bold_rtn
	PUSH	HL		; Preserve HL through routine
	LD	B,8		; 8 DBs to modify
Bold1	LD	A,(HL)		; Get line of character
	SRL	A		; Rotate left,
	OR	(HL)		; and add to the previous version (form bold)
	LD	(HL),A		; resave DB
	INC	HL		; next line 
	DJNZ	Bold1		; And back again for more
	POP	HL		; Restore HL
	RET

JItalics
	DB	#C9		; 0 = on, #C9 = off
Italic_rtn
	PUSH	HL		; Save HL through routine
	LD	B,04		; First 4 characters moved right
Ital1	LD	A,(HL)		; Get DB
	SRL	A		; Move right
	LD	(HL),A		; And resave
	INC	HL		; Next DB
	DJNZ	Ital1
	POP	HL		; Restore HL
	RET

JUnder	DB	#C9		; 0 = on, #c9 = off
Under_rtn
	PUSH	HL		; Save HL
	LD	B,7
Und1	INC	HL		; Move up 7
	DJNZ	Und1
	LD	A,(JBold)	; Is bold on?
	OR	A
	JR	Z,Und2		; Yes, skip past
	LD	A,85		; If no on, then Semi-solid line
	JR	Z,Und3
Und2	CPL			; If on, then solid underline
Und3	LD	(HL),A		; Save bottom line
	POP	HL
	RET

JInverse
	DB	#C9		; 0 = on, #c9 = off
Inverse
	PUSH	HL		; Save HL
	LD	B,8
Inv1	LD	A,(HL)		; Get DB
	CPL			; turn it inverse
	LD	(HL),A		; Resave
	INC	HL		; next DB
	DJNZ	Inv1
	POP	HL		; restore HL
	RET

IF Colour
JSmash	DB	#C9		; 0 = on, #C9 = off
Smash	PUSH	HL		; Save HL
	LD	B,8
	XOR	A
Sm1	LD	(HL),A		; 0 all DBs -- ie, concealed
	INC	HL
	DJNZ	Sm1
	POP	HL
	RET
ENDIF

ROMDIS
	push af
	CALL	KL_U_ROM_DISABLE	; Disable upper rom (for m4)
	LD	(RomState),A
	pop af
	Ret

ROMEN
	push af
	LD	A,(RomState)
	CALL	KL_ROM_RESTORE ; Restore m4.
	pop af
	ret