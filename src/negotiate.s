; Streaming Telnet decoder: never reads ahead or waits for another byte.
; States: data, IAC, option, SB option, SB payload, SB IAC.
ResetTelnet
    xor a
    ld hl,TelnetState
    ld b,TelnetStateEnd-TelnetState
ResetTelnetLoop
    ld (hl),a
    inc hl
    djnz ResetTelnetLoop
    ret
TelnetByte
    ld c,a
    ld a,(TelnetState)
    or a
    jr z,TelnetData
    cp 1
    jp z,TelnetIAC
    cp 2
    jp z,TelnetOptionByte
    cp 3
    jr z,TelnetSBOption
    cp 4
    jr z,TelnetSBData
    ; IAC within subnegotiation: escaped IAC or end marker.
    ld a,c
    cp SE
    jp z,TelnetSBEnd
    cp IAC
    jr z,TelnetSBQuoted
    ; Malformed SB: abandon it and interpret the new IAC command.
    jp TelnetIAC
TelnetData
    ld a,c
    cp IAC
    jp nz,PrintChar
    ld a,1
    ld (TelnetState),a
    ret
TelnetIAC
    xor a
    ld (TelnetState),a
    ld a,c
    cp IAC
    jp z,PrintChar
    cp SB
    jr z,TelnetStartSB
    cp WILL
    ret c
    cp DO+1
    jr c,TelnetStartOption
    cp DONT
    ret nz
TelnetStartOption
    ld (TelnetVerb),a
    ld a,2
    ld (TelnetState),a
    ret
TelnetStartSB
    ld a,3
    ld (TelnetState),a
    ret
TelnetSBOption
    ld a,c
    ld (TelnetSBType),a
    xor a
    ld (TelnetSBCount),a
    ld a,4
    ld (TelnetState),a
    ret
TelnetSBData
    ld a,c
    cp IAC
    jr nz,TelnetSBPayload
    ld a,5
    ld (TelnetState),a
    ret
TelnetSBQuoted
    ld a,4
    ld (TelnetState),a
TelnetSBPayload
    ld a,(TelnetSBCount)
    or a
    jr nz,TelnetSBMore
    ld a,c
    ld (TelnetSBFirst),a
    xor a
TelnetSBMore
    cp 255
    ret z
    inc a
    ld (TelnetSBCount),a
    ret
TelnetSBEnd
    xor a
    ld (TelnetState),a
    ld a,(LocalTT)
    or a
    ret z
    ld a,(TelnetSBType)
    cp CMD_TERMINAL_TYPE
    ret nz
    ld a,(TelnetSBCount)
    cp 1
    ret nz
    ld a,(TelnetSBFirst)
    cp 1                       ; TERMINAL-TYPE SEND
    ret nz
    ld hl,TelnetTypeReply
    ld b,11
    jp SendBytes
TelnetOptionByte
    xor a
    ld (TelnetState),a
    ld a,c
    ld (TelnetOption),a
    call printTelCmd
    ld a,(TelnetVerb)
    cp DO
    jr z,TelnetDO
    cp DONT
    jr z,TelnetDONT
    cp WILL
    jr z,TelnetWILL
    ; WONT: acknowledge only if the peer's option was previously enabled.
    call FindRemoteOption
    ret nc
    ld a,(hl)
    or a
    ret z
    ld (hl),0
    ld a,DONT
    jr TelnetReplyOption
TelnetWILL
    call FindRemoteOption
    ld a,DONT
    jr nc,TelnetReplyOption
    ld a,(hl)
    or a
    ret nz
    ld (hl),1
    ld a,DO
    jr TelnetReplyOption
TelnetDONT
    call FindLocalOption
    ret nc
    ld a,(hl)
    or a
    ret z                     ; Never echo an acknowledgement/refusal
    ld (hl),0
    ld a,WONT
    jr TelnetReplyOption
TelnetDO
    call FindLocalOption
    ld a,WONT
    jr nc,TelnetReplyOption
    ld a,(hl)
    or a
    ret nz                    ; Duplicate requests must not loop
    ld (hl),1
    ld a,WILL
    call TelnetReplyOption
    ld a,(TelnetOption)
    cp CMD_NAWS
    ret nz
    ld hl,TelnetWindowReply
    ld b,9
    jp SendBytes
TelnetReplyOption
    ld (TelnetOptionReply+1),a
    ld a,(TelnetOption)
    ld (TelnetOptionReply+2),a
    ld hl,TelnetOptionReply
    ld b,3
    jp SendBytes
FindLocalOption
    ld a,(TelnetOption)
    ld hl,LocalTT
    cp CMD_TERMINAL_TYPE
    jr z,TelnetSupported
    ld hl,LocalNAWS
    cp CMD_NAWS
    jr z,TelnetSupported
    ld hl,LocalSGA
    cp 3
    jr z,TelnetSupported
    or a
    ret
FindRemoteOption
    ld a,(TelnetOption)
    ld hl,RemoteEcho
    cp CMD_ECHO
    jr z,TelnetSupported
    ld hl,RemoteSGA
    cp 3
    jr z,TelnetSupported
    or a
    ret
TelnetSupported
    scf
    ret

; Send B bytes at HL. Only the M4 send command is issued here, never recv.
; Preserve parser registers and wait before reusing its shared packet buffer.
SendBytes
    push af
    push bc
    push de
    push hl
SendBytesWait
    ld a,(ix)
    cp 2
    jr z,SendBytesWait
    or a
    jr nz,SendBytesDone
    ld a,b
    ld (sendsize),a
    add a,5
    ld (cmdsend),a
    xor a
    ld (sendsize+1),a
    ld c,b
    ld b,0
    ld de,sendtext
    ldir
    ld hl,cmdsend
    call sendcmd
SendBytesDone
    pop hl
    pop de
    pop bc
    pop af
    ret
TelnetTypeReply: db IAC,SB,CMD_TERMINAL_TYPE,0,"VT100",IAC,SE
TelnetWindowReply: db IAC,SB,CMD_NAWS,0,80,0,screen_depth,IAC,SE
TelnetOptionReply: db IAC,0,0
TelnetState: db 0
TelnetVerb: db 0
TelnetOption: db 0
TelnetSBType: db 0
TelnetSBCount: db 0
TelnetSBFirst: db 0
LocalTT: db 0
LocalNAWS: db 0
LocalSGA: db 0
RemoteEcho: db 0
RemoteSGA: db 0
TelnetStateEnd:

printTelCmd:
    ld a, (printTelCmdFlag)
    or a              ; Check if the flag is zero
    ret z             ; Return if flag is off
	; Load the Telnet command byte
    ld hl, RECV_STRING
    call disptextz
    ld   a,(TelnetVerb)
    ; Compare and jump to respective handlers
    cp   DO
    jp   z, handle_do
    cp   WILL
    jp   z, handle_will
    call cmdtoascii
    call second_cmd
    ret

    ; Handler for DO command
handle_do:
    ld   hl, do_string  ; Pointer to a string representing "DO"
    call disptextz
    call second_cmd
    call crlf
    ret

; Handler for WILL command
handle_will:
    ld   hl, will_string  ; Pointer to a string representing "WILL"
    call disptextz
    call second_cmd
     call crlf
    ret

second_cmd:
    ld		a,(TelnetOption)
    cp		CMD_NAWS	
    jp   z, handle_naws
    cp      CMD_ECHO
    jp   z, handle_echo
    cp    CMD_TERMINAL_TYPE
    jp   z, handle_tt
    call cmdtoascii

    ret

handle_naws:
    ld   hl, naws_String
    call disptextz
    ret

handle_echo:
    ld   hl, echo_String
    call disptextz
    ret

handle_tt:
    ld   hl, TT_STRING
    call disptextz
    ret



cmdtoascii:
    ld (TelDebugValue), a
    ld hl, TelDebugValue
    call dispdec
    ld a, " "
    call printchar
    ret



    ; Strings representing commands
TelDebugValue: db 0
do_string:    db 'DO ', 0
will_string:  db 'WILL ', 0
NAWS_String: db ' NAWS ', 0 
ECHO_STRING: db ' ECHO ',0
TT_STRING: db ' TERMINAL_TYPE ',0
RECV_STRING: db 'RECV ',0

    ; This is the Telnet negotiation options debug display flag.
printTelCmdFlag:  db 0   ; 0 = off, 1 = on
msgPrintTelOn:    db "                              NEGOTIATION DEBUG ON                             ",0
msgPrintTelOff:   db "                              NEGOTIATION DEBUG OFF                            ", 0


; telnet negotiation codes
DO 				equ 0xfd
WONT 			equ 0xfc
WILL 			equ 0xfb
DONT 			equ 0xfe
CMD 			equ 0xff
IAC     equ 255   ; Interpret as Command
SB      equ 250   ; Subnegotiation Begin
SE      equ 240   ; Subnegotiation End
CMD_ECHO 		equ 1
CMD_TERMINAL_TYPE equ 24
CMD_NAWS            equ 31
