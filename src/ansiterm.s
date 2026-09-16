print "ANSI / VT100 FOUNDATION"
; Streaming parser. State survives arbitrary receive boundaries.
; 0=text, 1=ESC, 2=CSI, 3=ESC intermediate, 4=discard CSI,
; 5=control string, 6=ESC inside control string.
; NumberBuffer has 16 parameters plus an end marker; 253 saturates
; numeric input, 254 marks the end, and 255 means omitted.
Ansi
    push hl
    push de
    push bc
    push af
    ld c,a
    cp 24                       ; CAN / SUB cancel an incomplete sequence
    jp z,AnsiExit
    cp 26
    jp z,AnsiExit
    ld a,(AnsiState)
    cp 5
    jp nc,AnsiString
    ld a,c
    cp 27
    jp z,AnsiEscape
    cp 32
    jp c,AnsiControl
    cp 127
    jp z,AnsiMore
    ld a,(AnsiState)
    or a
    jp z,AnsiText
    cp 1
    jp z,AnsiEscByte
    cp 3
    jp z,AnsiIntermediate
    cp 4
    jp z,AnsiDiscard

    ; CSI parameters, private prefix, intermediate bytes, then final.
    ld a,c
    cp "0"
    jr c,AnsiNotDigit
    cp "9"+1
    jp c,AnsiNumber
AnsiNotDigit
    cp ";"
    jp z,AnsiSemi
    cp "?"
    jr nz,AnsiNotPrivate
    ld a,(AnsiParamCount)
    or a
    jp nz,AnsiDiscardStart
    ld a,(AnsiPrivate)
    or a
    jp nz,AnsiDiscardStart
    ld hl,(NumberPos)
    ld a,(hl)
    cp 255
    jp nz,AnsiDiscardStart
    ld a,1
    ld (AnsiPrivate),a
    jp AnsiMore
AnsiNotPrivate
    cp #40
    jp c,AnsiDiscardStart
    cp #7F
    jp nc,AnsiExit
    ld hl,(NumberPos)
    inc hl
    ld (hl),254
    call HideCursor
    ld hl,NumberBuffer
    ld a,(AnsiPrivate)
    or a
    jp nz,AnsiPrivateFinal
    ld a,c
    cp "m"
    jp z,SGR
    ; Cursor/edit operations cancel a pending right-margin wrap.
    cp "A"
    jp z,CUU
    cp "B"
    jp z,CUD
    cp "C"
    jp z,CUF
    cp "D"
    jp z,CUB
    cp "H"
    jp z,CUP
    cp "f"
    jp z,CUP
    cp "J"
    jp z,ED
    cp "K"
    jp z,EL
    cp "n"
    jp z,DeviceStatus
    cp "c"
    jp z,DeviceAttributes
    cp "r"
    jp z,SetMargins
    cp "s"
    jp z,SCP
    cp "u"
    jp z,RestorePosition
    jp AnsiExit

AnsiEscape
    ld a,1
    ld (AnsiState),a
    jp AnsiMore
AnsiEscByte
    call HideCursor
    ld a,c
    cp "Z"
    jp z,SendDeviceAttributes
    cp "("
    jp z,DesignateG0
    cp ")"
    jp z,DesignateG1
    cp "D"
    jp z,IndexCommand
    cp "E"
    jp z,NextLineCommand
    cp "M"
    jp z,ReverseIndexCommand
    cp "7"
    jp z,SaveDECCursor
    cp "8"
    jp z,RestoreDECCursor
    cp "["
    jr z,AnsiCSI
    cp "]"
    jr z,AnsiStringStart
    cp "P"
    jr z,AnsiStringStart
    cp "^"
    jr z,AnsiStringStart
    cp "_"
    jr z,AnsiStringStart
    cp "c"
    jp z,AnsiReset
    cp #20
    jp c,AnsiExit
    cp #30
    jp nc,AnsiExit
    ld a,255
    ld (CharsetTarget),a
    ld a,3                     ; Consume e.g. ESC ( B without executing CSI B
    ld (AnsiState),a
    jp AnsiMore
AnsiIntermediate
    jp DesignateCharacterSet
AnsiIgnoreIntermediate
    ld a,c
    cp #30
    jp nc,AnsiExit
    jp AnsiMore
AnsiCSI
    ld a,2
    ld (AnsiState),a
    xor a
    ld (AnsiPrivate),a
    ld (AnsiParamCount),a
    ld hl,NumberBuffer
    ld (NumberPos),hl
    ld (hl),255
    jp AnsiMore
AnsiStringStart
    ld a,5
    ld (AnsiState),a
    jp AnsiMore
AnsiString
    ld a,c
    cp 7                       ; BEL or ST ends an unsupported control string
    jp z,AnsiExit
    ld a,(AnsiState)
    cp 6
    jr nz,AnsiStringByte
    ld a,c
    cp #5C
    jp z,AnsiExit
AnsiStringByte
    ld a,c
    cp 27
    ld a,5
    jr nz,AnsiStringSet
    inc a
AnsiStringSet
    ld (AnsiState),a
    jp AnsiMore
AnsiDiscardStart
    ld a,4
    ld (AnsiState),a
    jp AnsiMore
AnsiDiscard
    ld a,c
    cp #40
    jp c,AnsiMore
    cp #7F
    jp c,AnsiExit
    jp AnsiMore
AnsiSemi
    ld a,(AnsiParamCount)
    cp 15
    jp nc,AnsiDiscardStart
    inc a
    ld (AnsiParamCount),a
    ld hl,(NumberPos)
    inc hl
    ld (NumberPos),hl
    ld (hl),255
    jp AnsiMore
AnsiNumber
    ld hl,(NumberPos)
    ld a,(hl)
    cp 255
    jr nz,AnsiAccumulate
    xor a
AnsiAccumulate
    ; Saturate before multiplying, avoiding byte overflow and sentinels.
    cp 25
    jr c,AnsiMultiply
    jr nz,AnsiSaturate
    ld a,c
    sub "0"
    cp 4
    jr nc,AnsiSaturate
    add a,250
    jr AnsiStoreNumber
AnsiMultiply
    ld b,a
    add a,a
    add a,a
    add a,b
    add a,a
    add a,c
    sub "0"
    jr AnsiStoreNumber
AnsiSaturate
    ld a,253
AnsiStoreNumber
    ld (hl),a
    jp AnsiMore
AnsiPrivateFinal
    ld a,c
    cp "h"
    ld b,1
    jr z,PrivateModeLoop
    cp "l"
    jp nz,AnsiExit
    ld b,0
PrivateModeLoop
    call GetNumber
    cp 254
    jp z,AnsiExit
    cp 1
    jr z,SetCursorKeyMode
    cp 6
    jr z,SetOriginMode
    cp 7
    jr nz,PrivateModeLoop
    ld a,b
    ld (AutoWrap),a
    call CancelWrap
    jr PrivateModeLoop
SetCursorKeyMode
    ld a,b
    ld (CursorKeyMode),a
    jr PrivateModeLoop
SetOriginMode
    ld a,b
    ld (OriginMode),a
    push hl
    call HomeCursor
    pop hl
    jr PrivateModeLoop
AnsiReset
    call HideCursor
    call AllOff
    call ResetTerminalModes
    ld hl,0
    ld (CursorPosition),hl
    ld (Cursor_Pos),hl
    call CancelWrap
    jp EraseAll
AnsiControl
    ld a,c
    cp 7
    jr z,AnsiText
    cp 8
    jr z,AnsiText
    cp 9
    jr z,AnsiText
    cp 10
    jr z,AnsiText
    cp 11
    jr z,AnsiText
    cp 12
    jr z,AnsiText
    cp 14
    jp z,SelectG1
    cp 15
    jp z,SelectG0
    cp 13
    jp nz,AnsiMore
AnsiText
    ld a,c
    call ScreenWrite
    jp AnsiMore
AnsiExit
    xor a
    ld (AnsiState),a
    ld (JChangeCursor),a
AnsiMore
    pop af
    pop bc
    pop de
    pop hl
    ret

HideCursor
    push bc
    push de
    push hl
    ld a,(CursorOn)
    or a
    call nz,ToggleCursor
    xor a
    ld (CursorOn),a
    ld (CursorCount),a
    ld a,#C9
    ld (JChangeCursor),a
    pop hl
    pop de
    pop bc
    ret
CancelWrap
    xor a
    ld (WrapPending),a
    ret
GetNumber
    ld a,(hl)
    cp 254
    ret z
    inc hl
    ret
GetCount
    call GetNumber
    cp 254
    jr nc,DefaultCount
    or a
    ret nz
DefaultCount
    ld a,1
    ret
CUU
    call CancelWrap
    call GetCount
    ld b,a
    ld a,(ScrollTop)
    ld e,a
    ld a,(CursorPosition)
    cp e
    jr nc,CUUBound
    ld e,0                    ; Absolute cursor may be above the region
CUUBound
    sub b
    jr c,CUUClamp
    cp e
    jr nc,SetRow
CUUClamp
    ld a,e
    jr SetRow
CUD
    call CancelWrap
    call GetCount
    ld b,a
    ld a,(ScrollBottom)
    ld e,a
    ld a,(CursorPosition)
    cp e
    jr c,CUDBound
    jr z,CUDBound
    ld e,screen_depth-1        ; Absolute cursor may be below the region
CUDBound
    add a,b
    jr c,CUDClamp
    cp e
    jr c,SetRow
CUDClamp
    ld a,e
SetRow
    ld (CursorPosition),a
    jp AnsiExit
CUB
    call CancelWrap
    call GetCount
    ld b,a
    ld a,(CursorPosition+1)
    sub b
    jr nc,SetColumn
    xor a
    jr SetColumn
CUF
    call CancelWrap
    call GetCount
    ld b,a
    ld a,(CursorPosition+1)
    add a,b
    jr c,LastColumn
    cp 80
    jr c,SetColumn
LastColumn
    ld a,79
SetColumn
    ld (CursorPosition+1),a
    jp AnsiExit
CUP
    call CancelWrap
    call GetCount
    dec a
    ld e,a
    ld a,(OriginMode)
    or a
    jr z,CupAbsolute
    ld a,(ScrollTop)
    add a,e
    ld e,a
    ld a,(ScrollBottom)
    jr nc,CupLimit
    ld e,a
    jr CupLimit
CupAbsolute
    ld a,screen_depth-1
CupLimit
    cp e
    jr nc,CupRow
    ld e,a
CupRow
    call GetCount
    cp 81
    jr c,CupColumn
    ld a,80
CupColumn
    dec a
    ld d,a
    ld (CursorPosition),de
    jp AnsiExit
RestorePosition
    call CancelWrap
    jp RCP

; Erasure includes the cursor cell and never moves the cursor.
ED
    call CancelWrap
    call GetNumber
    cp 254
    jr c,EDMode
    xor a
EDMode
    or a
    jr z,EraseAfter
    cp 1
    jr z,EraseBefore
    cp 2
    jp nz,AnsiExit
EraseAll
    ld hl,0
    ld bc,80*screen_depth
    jp EraseCells
CursorIndex
    ld a,(CursorPosition)
    ld hl,0
    ld de,80
    or a
    jr z,CursorIndexColumn
CursorIndexRow
    add hl,de
    dec a
    jr nz,CursorIndexRow
CursorIndexColumn
    ld a,(CursorPosition+1)
    ld e,a
    ld d,0
    add hl,de
    ret
EraseAfter
    call CursorIndex
    ex de,hl
    ld hl,80*screen_depth
    or a
    sbc hl,de
    ld b,h
    ld c,l
    ld hl,(CursorPosition)
    jp EraseCells
EraseBefore
    call CursorIndex
    inc hl
    ld b,h
    ld c,l
    ld hl,0
    jp EraseCells
EL
    call CancelWrap
    call GetNumber
    cp 254
    jr c,ELMode
    xor a
ELMode
    ld hl,(CursorPosition)
    ld b,0
    or a
    jr z,EraseLineAfter
    cp 1
    jr z,EraseLineBefore
    cp 2
    jp nz,AnsiExit
    ld c,80
    ld h,0
    jr EraseCells
EraseLineBefore
    ld c,h
    inc c
    ld h,0
    jr EraseCells
EraseLineAfter
    ld a,80
    sub h
    ld c,a
EraseCells
    call romdis
    call FindCursor
    call ScreenBlank
    call romen
    jp AnsiExit
ScreenBlank
    ld a,b
    or c
    ret z
ScreenBlank_Next
    push hl
    ld e,8
ScreenBlank_Down
    ld (hl),0                  ; VT100 erases to the normal background
    ld a,h
    add a,8
    ld h,a
    dec e
    jr nz,ScreenBlank_Down
    pop hl
    call ScreenBlank_Across
    dec bc
    ld a,c
    or b
    jr nz,ScreenBlank_Next
    ret
ScreenBlank_Across
    inc hl
    ld a,h
    and 7
    or #C0
    ld h,a
    ret

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
