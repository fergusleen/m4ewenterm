; VT100 editing modes. Rows and margins are zero-based internally.
ResetTerminalModes
    xor a
    ld (AnsiState),a
    ld (WrapPending),a
    ld (OriginMode),a
    ld (CursorKeyMode),a
    ld (ScrollTop),a
    ld (DecSavedValid),a
    ld (G0Charset),a
    ld (G1Charset),a
    ld (ActiveCharset),a
    ld a,screen_depth-1
    ld (ScrollBottom),a
    ld a,1
    ld (AutoWrap),a
    jp RefreshGlyphMode
HomeCursor
    call CancelWrap
    ld hl,0
    ld a,(OriginMode)
    or a
    jr z,HomeCursorSet
    ld a,(ScrollTop)
    ld l,a
HomeCursorSet
    ld (CursorPosition),hl
    ret
SetMargins
    ld a,(AnsiParamCount)
    cp 2
    jp nc,AnsiExit
    call GetCount
    dec a
    ld e,a
    call GetNumber
    cp 254
    jr nc,MarginDefaultBottom
    or a
    jr nz,MarginBottom
MarginDefaultBottom
    ld a,screen_depth
MarginBottom
    dec a
    cp screen_depth
    jp nc,AnsiExit
    cp e
    jp c,AnsiExit
    jp z,AnsiExit
    ld (ScrollBottom),a
    ld a,e
    ld (ScrollTop),a
    call HomeCursor
    jp AnsiExit
IndexCommand
    call CancelWrap
    call SW_LF_All
    jp AnsiExit
NextLineCommand
    call CancelWrap
    ld hl,(CursorPosition)
    ld h,0
    call SW_LFn
    jp AnsiExit
ReverseIndexCommand
    call CancelWrap
    ld a,(ScrollTop)
    ld hl,(CursorPosition)
    cp l
    jr z,ReverseScroll
    ld a,l
    or a
    jr z,ReverseStay
    dec l
ReverseStay
    ld (CursorPosition),hl
    jp AnsiExit
ReverseScroll
    call ScrollDown
    jp AnsiExit

; Full-screen upward scrolling retains the fast CRTC offset path. A partial
; region must copy pixels so the header/footer outside its margins stay fixed.
ScrollUp
    ld a,(ScrollTop)
    or a
    jr nz,ScrollPartialUp
    ld a,(ScrollBottom)
    cp screen_depth-1
    jp z,ScrollFullUp
ScrollPartialUp
    call romdis
    ld a,(ScrollTop)
    ld (ScrollRow),a
ScrollUpRow
    ld e,a                     ; destination row
    inc a                      ; source row
    call CopyTextRow
    ld a,(ScrollRow)
    inc a
    ld (ScrollRow),a
    ld e,a
    ld a,(ScrollBottom)
    cp e
    ld a,e
    jr nz,ScrollUpRow
    jr ScrollBlankRow
ScrollDown
    call romdis
    ld a,(ScrollBottom)
    ld (ScrollRow),a
ScrollDownRow
    ld e,a
    dec a
    call CopyTextRow
    ld a,(ScrollRow)
    dec a
    ld (ScrollRow),a
    ld e,a
    ld a,(ScrollTop)
    cp e
    ld a,e
    jr nz,ScrollDownRow
ScrollBlankRow
    ld l,a
    ld h,0
    call FindCursor
    ld bc,80
    call ScreenBlank
    call romen
    ret

; Copy one complete rendered row (attributes included): A=source, E=dest.
; Each character column wraps within the CPC's 2K raster bank, so this also
; works after any number of previous hardware scrolls. Does not touch IX/IY.
CopyTextRow
    ld l,a
    ld h,0
    push de
    call FindCursor
    pop de
    push hl
    ld l,e
    ld h,0
    call FindCursor
    ex de,hl
    pop hl
    ; A row is contiguous unless its first raster crosses the 2K ring edge.
    ; Keep the column copier for either wrapped row; all other rows use LDIR.
    ld a,h
    and 7
    cp 7
    jr nz,CopyCheckDestination
    ld a,l
    cp 177
    jr nc,CopyRowWrapped
CopyCheckDestination
    ld a,d
    and 7
    cp 7
    jr nz,CopyRowBlocks
    ld a,e
    cp 177
    jr nc,CopyRowWrapped
CopyRowBlocks
    ld a,8
CopyRowBlockRaster
    push af
    push hl
    push de
    ld bc,80
    ldir
    pop de
    pop hl
    ld a,h
    add a,8
    ld h,a
    ld a,d
    add a,8
    ld d,a
    pop af
    dec a
    jr nz,CopyRowBlockRaster
    ret
CopyRowWrapped
    ld c,80
CopyRowColumn
    push hl
    push de
    ld b,8
CopyRowRaster
    ld a,(hl)
    ld (de),a
    ld a,h
    add a,8
    ld h,a
    ld a,d
    add a,8
    ld d,a
    djnz CopyRowRaster
    pop de
    pop hl
    call ScreenBlank_Across
    ex de,hl
    call ScreenBlank_Across
    ex de,hl
    dec c
    jr nz,CopyRowColumn
    ret

SaveDECCursor
    ld hl,(CursorPosition)
    ld (DecSavedCursor),hl
    ld a,(OriginMode)
    ld (DecSavedOrigin),a
    ld a,(AutoWrap)
    ld (DecSavedWrap),a
    ld a,(WrapPending)
    ld (DecSavedPending),a
    ld a,(JBold)
    ld (DecSavedAttrs+0),a
    ld a,(JItalics)
    ld (DecSavedAttrs+1),a
    ld a,(JUnder)
    ld (DecSavedAttrs+2),a
    ld a,(JInverse)
    ld (DecSavedAttrs+3),a
    ld a,(JSmash)
    ld (DecSavedAttrs+4),a
    ld a,(JHighInt)
    ld (DecSavedAttrs+5),a
    ld a,(fontset)
    ld (DecSavedAttrs+6),a
    ld a,(backcolour)
    ld (DecSavedAttrs+7),a
    ld a,(forecolour)
    ld (DecSavedAttrs+8),a
    ld hl,G0Charset
    ld de,DecSavedSets
    ld bc,3
    ldir
    ld a,1
    ld (DecSavedValid),a
    jp AnsiExit
RestoreDECCursor
    ld a,(DecSavedValid)
    or a
    jr nz,RestoreDECValid
    call AllOff
    xor a
    ld (OriginMode),a
    ld (G0Charset),a
    ld (G1Charset),a
    ld (ActiveCharset),a
    ld a,1
    ld (AutoWrap),a
    call HomeCursor
    jp GlyphModeExit
RestoreDECValid
    ld a,(DecSavedOrigin)
    ld (OriginMode),a
    ld a,(DecSavedWrap)
    ld (AutoWrap),a
    ld a,(DecSavedPending)
    ld (WrapPending),a
    ld a,(DecSavedAttrs+0)
    ld (JBold),a
    ld a,(DecSavedAttrs+1)
    ld (JItalics),a
    ld a,(DecSavedAttrs+2)
    ld (JUnder),a
    ld a,(DecSavedAttrs+3)
    ld (JInverse),a
    ld a,(DecSavedAttrs+4)
    ld (JSmash),a
    ld a,(DecSavedAttrs+5)
    ld (JHighInt),a
    ld a,(DecSavedAttrs+6)
    ld (fontset),a
    ld a,(DecSavedAttrs+7)
    ld (backcolour),a
    ld a,(DecSavedAttrs+8)
    ld (forecolour),a
    ld hl,DecSavedSets
    ld de,G0Charset
    ld bc,3
    ldir
    ld hl,(DecSavedCursor)
    ld a,(OriginMode)
    or a
    jr z,RestoreDECPosition
    ld a,(ScrollTop)
    cp l
    jr c,RestoreDECBelow
    jr z,RestoreDECBelow
    ld l,a
    call CancelWrap
RestoreDECBelow
    ld a,(ScrollBottom)
    cp l
    jr nc,RestoreDECPosition
    ld l,a
    call CancelWrap
RestoreDECPosition
    ld (CursorPosition),hl
    jp GlyphModeExit

; G0/G1 designation: B=ASCII/CP437, 0=DEC special graphics, A=UK.
DesignateG0
    xor a
    jr DesignateStart
DesignateG1
    ld a,1
DesignateStart
    ld (CharsetTarget),a
    ld a,3
    ld (AnsiState),a
    jp AnsiMore
DesignateCharacterSet
    ld a,(CharsetTarget)
    cp 2
    jp nc,AnsiIgnoreIntermediate
    ld e,a
    ld d,0
    ld hl,G0Charset
    add hl,de
    ld a,c
    ld b,0
    cp "B"
    jr z,DesignateSet
    inc b
    cp "0"
    jr z,DesignateSet
    inc b
    cp "A"
    jp nz,AnsiExit
DesignateSet
    ld (hl),b
    jp GlyphModeExit
SelectG0
    xor a
    ld (ActiveCharset),a
    call RefreshGlyphMode
    jp AnsiMore              ; SI/SO are allowed inside escape sequences
SelectG1
    ld a,1
    ld (ActiveCharset),a
    call RefreshGlyphMode
    jp AnsiMore

LoadTerminalGlyph
    ld c,a
    ld a,(ActiveCharset)
    or a
    ld a,(G0Charset)
    jr z,GlyphSetSelected
    ld a,(G1Charset)
GlyphSetSelected
    cp 1
    jr z,GlyphSpecial
    cp 2
    ld a,c
    jp nz,GetCP437Character
    cp "#"
    jp nz,GetCP437Character
    ld a,156                 ; CP437 pound sign
    jp GetCP437Character
GlyphSpecial
    ld a,c
    cp #5F
    jp c,GetCP437Character
    cp #7F
    jp nc,GetCP437Character
    sub #5F
    push hl
    push hl
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld de,DECGraphics
    add hl,de
    ex de,hl
    pop hl
    ld b,8
GlyphSpecialCopy
    ld a,(de)
    ld (hl),a
    inc de
    inc hl
    djnz GlyphSpecialCopy
    pop hl
    ret

DeviceAttributes
    ld a,(AnsiParamCount)
    or a
    jp nz,AnsiExit
    call GetNumber
    cp 254
    jr nc,SendDeviceAttributes
    or a
    jp nz,AnsiExit
SendDeviceAttributes
    ld hl,DeviceAttributesReply
    ld b,7
    call SendBytes
    jp AnsiExit
DeviceStatus
    ld a,(AnsiParamCount)
    or a
    jp nz,AnsiExit
    call GetNumber
    cp 5
    jr z,SendReady
    cp 6
    jp nz,AnsiExit
    ld hl,CursorReport
    ld (hl),27
    inc hl
    ld (hl),"["
    inc hl
    ld a,(CursorPosition)
    ld e,a
    ld a,(OriginMode)
    or a
    ld a,e
    jr z,ReportAbsolute
    ld a,(ScrollTop)
    ld d,a
    ld a,e
    sub d
ReportAbsolute
    inc a
    call ReportDecimal
    ld (hl),";"
    inc hl
    ld a,(CursorPosition+1)
    inc a
    call ReportDecimal
    ld (hl),"R"
    inc hl
    ld de,CursorReport
    or a
    sbc hl,de
    ld b,l
    ld hl,CursorReport
    call SendBytes
    jp AnsiExit
SendReady
    ld hl,ReadyReply
    ld b,4
    call SendBytes
    jp AnsiExit
ReportDecimal
    ld d,0
ReportTens
    cp 10
    jr c,ReportUnits
    sub 10
    inc d
    jr ReportTens
ReportUnits
    ld e,a
    ld a,d
    or a
    jr z,ReportOnlyUnits
    add a,"0"
    ld (hl),a
    inc hl
ReportOnlyUnits
    ld a,e
    add a,"0"
    ld (hl),a
    inc hl
    ret
DeviceAttributesReply: db 27,"[?1;0c"
ReadyReply: db 27,"[0n"
CursorReport: ds 12

; DEC special graphics, characters 5F..7E (eight raster bytes each).
DECGraphics
    db #00,#00,#00,#00,#00,#00,#00,#00 ; 5F
    db #10,#38,#7C,#FE,#7C,#38,#10,#00 ; 60
    db #55,#AA,#55,#AA,#55,#AA,#55,#AA ; 61
    db #00,#AE,#A4,#E4,#A4,#A4,#00,#00 ; 62
    db #00,#EE,#88,#CC,#88,#88,#00,#00 ; 63
    db #00,#EC,#8A,#8C,#8A,#EA,#00,#00 ; 64
    db #00,#8E,#88,#8C,#88,#E8,#00,#00 ; 65
    db #38,#6C,#6C,#38,#00,#00,#00,#00 ; 66
    db #30,#30,#FC,#30,#30,#00,#FC,#00 ; 67
    db #00,#A8,#E8,#E8,#E8,#AE,#00,#00 ; 68
    db #00,#AE,#A4,#A4,#A4,#44,#00,#00 ; 69
    db #18,#18,#18,#18,#F8,#00,#00,#00 ; 6A
    db #00,#00,#00,#00,#F8,#18,#18,#18 ; 6B
    db #00,#00,#00,#00,#1F,#18,#18,#18 ; 6C
    db #18,#18,#18,#18,#1F,#00,#00,#00 ; 6D
    db #18,#18,#18,#18,#FF,#18,#18,#18 ; 6E
    db #FF,#00,#00,#00,#00,#00,#00,#00 ; 6F
    db #00,#00,#FF,#00,#00,#00,#00,#00 ; 70
    db #00,#00,#00,#00,#FF,#00,#00,#00 ; 71
    db #00,#00,#00,#00,#00,#FF,#00,#00 ; 72
    db #00,#00,#00,#00,#00,#00,#00,#FF ; 73
    db #18,#18,#18,#18,#1F,#18,#18,#18 ; 74
    db #18,#18,#18,#18,#F8,#18,#18,#18 ; 75
    db #18,#18,#18,#18,#FF,#00,#00,#00 ; 76
    db #00,#00,#00,#00,#FF,#18,#18,#18 ; 77
    db #18,#18,#18,#18,#18,#18,#18,#18 ; 78
    db #18,#30,#60,#30,#18,#00,#FC,#00 ; 79
    db #60,#30,#18,#30,#60,#00,#FC,#00 ; 7A
    db #00,#FE,#6C,#6C,#6C,#6C,#6C,#00 ; 7B
    db #00,#02,#7E,#08,#10,#7E,#40,#00 ; 7C
    db #38,#6C,#64,#F0,#60,#E6,#FC,#00 ; 7D
    db #00,#00,#00,#00,#18,#00,#00,#00 ; 7E

; Cache only derived state; DEC restore recomputes it from restored modes.
GlyphModeExit
    call RefreshGlyphMode
    jp AnsiExit
RefreshGlyphMode
    push af
    push bc
    ld a,(JItalics)
    ld b,a
    ld a,(JBold)
    and b
    ld b,a
    ld a,(JUnder)
    and b
    ld b,a
    ld a,(JInverse)
    and b
    ld b,a
    ld a,(JSmash)
    and b
    jr z,GlyphModeBuffered
    ld a,(ActiveCharset)
    or a
    ld a,(G0Charset)
    jr z,GlyphModeCharset
    ld a,(G1Charset)
GlyphModeCharset
    or a
    jr z,GlyphModeStore
GlyphModeBuffered
    ld a,1
GlyphModeStore
    ld (BufferedGlyphRequired),a
    pop bc
    pop af
    ret
BufferedGlyphRequired: db 1
