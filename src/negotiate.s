            ; Negotiation code for telnet
            ; 
            ; Terminal type in progress. 6/12/2023 FL

			; call when CMD (0xFF) detected, read next two bytes of command
			; IY = socket structure ptr
negotiate:

			ld		bc,2
			call	recv
			;just dispose of these two bytes and ignore for now -FL ; What if telnet command longer?
            ;ret
			cp		0xFF
			jp		z, exit_close	
			cp		3
			jp		z, exit_close
            
			
            xor		a
			cp		c
			jr		nz, check_negotiate
			cp		b
			jr		z,negotiate	; keep looping, want a reply. Could do other stuff here!
			

; check here for IAC a second time, this means some type of subnegotiation
check_negotiate:	
            call printTelCmd ; uncomment for negotation info
			ld		a,(iy+6)
			cp		0xFD	; DO
			jr		nz, will_not
			ld		a,(iy+7)
			cp		CMD_NAWS	
            jr      nz, will_not
			;jr		nz, check_terminal_type ; return to this
			; negotiate window size
            ld      b,CMD_NAWS
            call send_tel_cmd
		
			ld		a,14
			ld		(cmdsend),a
			ld		hl,sendsize
			ld		(hl),9
			inc		hl
			ld		(hl),0
			inc		hl
			ld		(hl),IAC		; CMD
			inc		hl
			ld		(hl),SB		; SB sub negotiation
			inc		hl
			ld		(hl),CMD_NAWS
			inc		hl
			ld		(hl),0
			inc		hl
			ld		(hl),80
			inc		hl
			ld		(hl),0
			inc		hl
			ld		(hl),24
			inc		hl
			ld		(hl),IAC
			inc		hl
			ld		(hl),SE		; End of subnegotiation parameters.

_wait_send:	ld		a,(ix)
			cp		2			; send in progress?
			jr		z,_wait_send
			cp		0
			call	nz,exit_close	
			
			ld		hl, cmdsend
			call	sendcmd
			ret



will_not:
			
			ld		a,(iy+6)
            cp      SB          ; Subneg will be a number of bytes up to IAC SE
            ret     z
			cp		DO			; DO
			jr		nz, not_do
			ld		a,WONT			; WONT
			jr		next_telcmd
not_do:		cp		WILL			; WILL
			jr		nz, next_telcmd
			ld		a,DO			; DO

next_telcmd:

			ld		hl,sendsize
			ld		(hl),3
			inc		hl
			ld		(hl),0
			inc		hl
			ld		(hl),0xFF		; CMD
			inc		hl
			ld		(hl),a			;
			inc		hl
			ld		a,(iy+7)
			ld		(hl),a			; 
			
			ld		a,8
			ld		(cmdsend),a
			
			ld		hl, cmdsend
			call	sendcmd


			ret


check_terminal_type:
			; Check if the received command is CMD_TERMINAL_TYPE
            ld a, (iy+7)
            cp CMD_TERMINAL_TYPE
            jr nz, will_not

            ; If it is CMD_TERMINAL_TYPE, send Will Terminal-type
            ld b, CMD_TERMINAL_TYPE
            call send_tel_cmd

            ; Prepare to assemble a new packet
            ld		a,16
			ld		(cmdsend),a
			ld		hl,sendsize
            ; Set the packet size
            ld (hl), 10           ; Correct packet size (excluding size bytes)
            inc hl
            ld (hl), 0
            inc hl

            ; Start assembling the packet
            ld (hl), IAC         ; Start of Telnet command
            inc hl
            ld (hl), SB          ; Subnegotiation Begin
            inc hl
            ld (hl), CMD_TERMINAL_TYPE  ; Terminal Type Option
            inc hl
            ld (hl), 0           ; IS command
            inc hl

            ; Write "ANSI" string
            ld (hl), 'a'         ; ASCII for 'A'
            inc hl
            ld (hl), 'n'         ; ASCII for 'N'
            inc hl
            ld (hl), 's'         ; ASCII for 'S'
            inc hl
            ld (hl), 'i'         ; ASCII for 'I'
            inc hl


            ; End the subnegotiation
            ld (hl), IAC         ; Interpret as Command
            inc hl
            ld (hl), SE          ; Subnegotiation End


            ; Jump to wait/send routine
            jp _wait_send

; put cmd in b
send_tel_cmd:
			ld		a,8
			ld		(cmdsend),a
			ld		hl,sendsize
			ld		(hl),3
			inc		hl
			ld		(hl),0
			inc		hl
			ld		(hl),0xFF		; CMD
			inc		hl
			ld		(hl),0xFB		; WILL
			inc		hl
			ld		(hl),b          ; b is cmd
			
			ld		hl, cmdsend
			call	sendcmd
            ret

printTelCmd:
    ld a, (printTelCmdFlag)
    or a              ; Check if the flag is zero
    ret z             ; Return if flag is off
	; Load the Telnet command byte
    ld hl, RECV_STRING
    call disptextz
    ld   a,(iy+6)
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
    ld		a,(iy+7)
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
    ld (0x8A00), a
    ld hl, 0x8A00
    call dispdec
    ld a, " "
    call printchar
    ret



    ; Strings representing commands
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
