			;  Telnet functionality, send, recieve and M4 Board Identification

start_telnet:	


            ld hl, msgtest
            call disptextz
			call drawline
            call Check_m4
			call loop_ip


telnet_session:
            ld hl,msgconnecterror
            ld (ErrorContext),hl
			call romen
		    ld		hl,(0xFF02)	; get response buffer address
			push	hl
			pop		iy
			
			; get a socket
			
			ld		hl,cmdsocket
			call	sendcmd
			ld		a,(iy+3)
			cp		255
			ret		z

			; store socket in predefined packets
			
			ld		(csocket),a
			ld		(clsocket),a
			ld		(rsocket),a
			ld		(sendsock),a
			
			
			; multiply by 16 and add to socket status buffer
			
			sla		a
			sla		a
			sla		a
			sla		a
			
			ld		hl,(0xFF06)	; get sock info
			ld		e,a
			ld		d,0
			add		hl,de	; sockinfo + (socket*4)
			push	hl
			pop		ix		; ix ptr to current socket status
			


			; connect to server
			
			ld		hl,cmdconnect
			call	sendcmd
			ld		a,(iy+3)
			cp		255
            jr z,connect_failed
            call WaitForConnect
            or a
            jr z,connect_ok
connect_failed:
            call disp_error
            ld hl,cmdclose
            call sendcmd
            ret                  ; Unwind telnet_session back to the menu

; Poll the socket without blocking the keyboard. Only a real keypress counts;
; KM_READ_CHAR may leave A unchanged when it returns with carry clear.
WaitForConnect:
wait_connect:
            ld a,(ix)
            cp 1
            ret nz
            call km_read_char
            jr nc,wait_connect
            cp 27                ; Normal ESC (terminal mapping)
            jr z,connect_cancel
            cp #FC               ; Shift-ESC also cancels
            jr nz,wait_connect
connect_cancel:
            ld a,#FC
            ret

connect_ok:
            ld hl,msgsessionerror
            ld (ErrorContext),hl
            call ResetTerminalModes
            call ResetTelnet
            ld		hl,msgconnect
			call	disptextz


mainloop:	call	recv_noblock2
            jp c,exit_close
			
			call	km_read_char
			jr		nc,mainloop

			cp		0xFC			; ESC?
			jp		z, exit_close	
			cp		0x9				; TAB?
			jr		nz, no_pause
wait_no_tab:
			call	km_read_char
			cp		0x9
			jr		z, wait_no_tab
			
pause_loop:			
			call	km_read_char
			cp		0xFC			; ESC?
			jp		z, exit_close	
			cp		0x9				; TAB again to leave
			jr		nz, pause_loop
			jr		mainloop
no_pause:
            call EncodeKey
wait_send:
            ld a,(ix)
            cp 2
            jr z,wait_send
            or a
            jp nz,exit_close
            ld hl,cmdsend
            call sendcmd
            jp mainloop

; A = CPC firmware character. Build one complete M4 send packet.
; Bare cursor keys are F0=up, F1=down, F2=left, F3=right.
EncodeKey:
            ld hl,sendtext
            ld (hl),a
            ld b,1
            cp #F0
            jr c,EncodePlain
            cp #F4
            jr nc,EncodePlain
            sub #F0
            ld e,a
            ld d,0
            ld hl,ArrowFinals
            add hl,de
            ld c,(hl)
            ld hl,sendtext
            ld (hl),27
            inc hl
            ld a,(CursorKeyMode)
            or a
            ld a,"["
            jr z,EncodeArrowPrefix
            ld a,"O"
EncodeArrowPrefix:
            ld (hl),a
            inc hl
            ld (hl),c
            ld b,3
            jr EncodeLength
EncodePlain:
            cp 13
            jr nz,EncodeIAC
            inc hl
            ld (hl),10
            ld b,2
            jr EncodeLength
EncodeIAC:
            cp 255
            jr nz,EncodeLength
            inc hl
            ld (hl),255       ; Literal IAC must be escaped on Telnet
            ld b,2
EncodeLength:
            ld a,b
            ld (sendsize),a
            add a,5
            ld (cmdsend),a
            xor a
            ld (sendsize+1),a
            ret
ArrowFinals: db "ABDC"


recv_noblock2:
			push 	bc
			push 	de
			push 	hl
			
            ; Bound work per keyboard poll, while amortising M4 command overhead.
            ld bc,ReceiveBatchSize
			
			call 	recv
			cp 240
            jr nc,ReceiveFailed
			cp		3
			jr z,ReceiveFailed
			xor		a
			cp		c
			jr		nz, got_msg2
			cp		b
			jr		nz, got_msg2
            or a                 ; successful return: carry clear
			pop 	hl
			pop 	de
			pop 	bc
			ret

got_msg2:
            ; Sending a Telnet/terminal reply overwrites the M4 response area.
            ; Save the entire batch before any parser call can send a reply.
            push iy
            pop hl
            ld de,6
            add hl,de
            ld de,ReceiveBatch
            push bc
            ldir
            pop bc
            ld hl,ReceiveBatch
ReceiveBatchLoop:
            ld a,(hl)
            push bc
            push hl
            call TelnetByte
            pop hl
            pop bc
            inc hl
            dec bc
            ld a,b
            or c
            jr nz,ReceiveBatchLoop

recvdone:	
			
			pop		hl
			pop		de
			pop		bc
			ret
			


; Return socket errors to the session loop, unwinding all receive frames.
ReceiveFailed:
            pop hl
            pop de
            pop bc
            scf
            ret


recv:		; connection still active
			ld		a,(ix)			; 
			cp		3				; socket status  (3 == remote closed connection)
			ret		z
            cp 240
            ret nc
			; check if anything in buffer ?
			ld		a,(ix+2)
     
			cp		0
			jr		nz,recv_cont
			ld		a,(ix+3)
			cp		0
			jr		nz,recv_cont
			ld		bc,0
			ld		a,1	
			ret
recv_cont:			

			; set receive size
			ld		a,c
			ld		(rsize),a
			ld		a,b
			ld		(rsize+1),a

			ld		hl,cmdrecv
			call	sendcmd
			

			ld		a,(iy+3)
			cp		0				; all good ?

			jr		z,recv_ok
			ld		bc,0
			ret

recv_ok:			

			ld		c,(iy+4)
			ld		b,(iy+5)
			ret


			; display text
			; HL = text
			; BC = length

disptext:	xor		a
			cp		c
			jr		nz, not_dispend
			cp		b
			ret		z
not_dispend:
			ld 		a,(hl)
			push	bc
			call	printchar
			pop		bc
			inc		hl
			dec		bc
			jr		disptext

			; display text zero terminated
			; HL = text
disptextz:	
			ld 		a,(hl)
			or		a
			ret		z
			call	PRINTCHAR
			inc		hl
			jr		disptextz


drawline: 
			push af
			push bc
			ld a, 196
			call PrintChar80Times
			pop bc
			pop af

; Routine to print a character 80 times
; Input: A register holds the character to be printed
PrintChar80Times:
    		ld b, 80        ; Set loop counter to 80

PrintLoop:
			push bc         ; Save the loop counter
			call PrintChar  ; Call routine to print the character in A
			pop bc          ; Restore the loop counter
			djnz PrintLoop  ; Decrement B and jump if not zero

			ret             ; Return from routine

			;
			; Display error code in ascii (hex)
			;
	
			; a = error code
disp_error:
			cp		3
			jr		nz, not_rc3
			ld		hl,msgconnclosed
			jp		disptextz
not_rc3:	cp		0xFC
			jr		nz,notuser
			ld		hl,msguserabort
			jp		disptextz
notuser:
			push	af
            ld hl,(ErrorContext)
            call disptextz
			pop		bc
			ld		a,b
			srl		a
			srl		a
			srl		a
			srl		a
			add		a,0x90
			daa
			adc		a,0x40
			daa
			call	printchar
			ld		a,b
			and		0x0f
			add		a,0x90
			daa
			adc		a,0x40
			daa
			call	printchar
			ld		a,10
			call	printchar
			ld		a,13
			call	printchar
			ret

disphex:	ld		b,a
			srl		a
			srl		a
			srl		a
			srl		a
			add		a,0x90
			daa
			adc		a,0x40
			daa
			call	printchar
			ld		a,b
			and		0x0f
			add		a,0x90
			daa
			adc		a,0x40
			daa
			call	printchar
			ld		a,32
			call	printchar
			ret

exit_close:
			call crlf
			call	disp_error

			ld		hl,cmdclose
			call	sendcmd
            ret                  ; Return to server_selected, which owns the menu loop


			;
			; Send command to M4
			; HL = packet to send
			;
sendcmd:
			ld		bc,0xFE00
			ld		d,(hl)
			inc		d
sendloop:	inc		b
			outi ; Reads from (HL) and writes to the (C) port. HL is then incremented, and B is decremented.
			dec		d
			jr		nz,sendloop
			ld		bc,0xFC00
			out		(c),c
			ret


Check_m4
			ld		a,(m4_rom_num)
			cp		0xFF
			call	z,find_m4_rom	
			cp		0xFF
			jr		nz, found_m4
			
			ld		hl,msgnom4
			call	disptextz
            ret
			
found_m4:	ld		hl,msgfoundm4
			call	disptextz
            ret


find_m4_rom:
			ld		iy,m4_rom_name	; rom identification line
			ld		d,127		; start looking for from (counting downwards)
			
romloop:	push	de
			ld		c,d
			call	kl_rom_select		; system/interrupt friendly
			ld		a,(0xC000)
			cp		1
			jr		nz, not_this_rom
			ld		hl,(0xC004)	; get rsxcommand_table
			push	iy
			pop		de
cmp_loop:
			ld		a,(de)
			xor		(hl)			; hl points at rom name
			jr		z, match_char
not_this_rom:
			pop		de
			dec		d
			jr		nz, romloop
			ld		a,255		; not found!
			ret
			
match_char:
			ld		a,(de)
			inc		hl
			inc		de
			and		0x80
			jr		z,cmp_loop
			
			; rom found, store the rom number
			
			pop		de			;  rom number
			ld 		a,d
			ld		(m4_rom_num),a
			ret

escape_val:	cp		2
			jr		nz, has_value
			xor		a
			ret
has_value:	ld		d,0
			sub		2
			ld		e,a
dec_loop2:
			ld		a,(hl)
			cp		0x41	; a ?
			jr		nc,less_than_a2
			sub		0x30	; - '0'
			jr		next_dec2
less_than_a2:	
			sub		0x37	; - ('A'-10)
next_dec2:	inc	hl
			cp	0
			jr	nz, do_mul
			dec	e
			jr	nz, dec_loop2
			ld	a,d
			ret
do_mul:		ld	b,a
			ld	a,e
			cp	3
			jr	nz, not_3digits
			xor	a
a_mul100:		add	100
			djnz	a_mul100
			ld	d,a
			dec	e
			jr	nz, dec_loop2
			ret
not_3digits:		cp	2
			jr	nz, not_2digits
			xor	a
a_mul10:		add	10
			djnz	a_mul10
			add	d			
			ld	d,a
			dec	e
			jr	nz, dec_loop2
			ret
			ld	a,d
not_2digits:	ld	a,b
			add	d
			ret	




msgconnclosed:	db	10,13,"Remote host closed the connection.",10,13,0
msgsenderror:	db	10,13,"ERROR: ",0
msgconnect:		db	10,13,"Connected.",10,13,0
msgserverip:	db	10,13,"Enter hostname or IP[:port] (default port: 23):",10,13,0
msgnom4:		db	"No M4 board found.",10,13,0
msgfoundm4:		db	"M4 board detected",10,13,0
msgverfail:		db	", you need v1.1.0 or higher.",10,13,0
msgok:			db  ", OK.",10,13,0
msgconnecting:	db	10,13, "Connecting to IP ",0
msgconnectcancel: db " (ESC cancels)",0
msgport:		db  " port ",0
msgresolve:		db	10,13, "Resolving: ",0
msgfail:		db 	", failed!", 10, 13, 0
msgtitle:		db	"CPC telnet client v101 beta  Duke 2018",10,13,0
msgtest:        db  "M4TERM v2.0 VT100 2026 github.com/fergusleen/m4ewenterm",10,13,0
msgtitle2:		db  "==========https://github.com/fergusleen/m4ewenterm=========",10,13,0
msguserabort:	db	10,13,"Cancelled (ESC)", 10, 13,0
cmdsocket:		db	5
				dw	C_NETSOCKET
				db	0x0,0x0,0x6		; domain, type, protocol (TCP/IP)

cmdconnect:		db	9	            ; this command is 9 bytes, we can access these bytes directly below
				dw	C_NETCONNECT
csocket:		db	0
; ip_addr:		db	162,254,68,82		; ip addr
; port:			dw	464		; port
ip_addr:		db	1,0,0,127		; ip addr
port:			dw	23		; port
; ip_addr:		db	230,139,13,64		; ip addr
; port:			dw	23		; port


cmdsend:		db	0			; we can ignore value of this byte (part of early design)	
				dw	C_NETSEND
sendsock:		db	0
sendsize:		dw	0			; size
sendtext:		ds	255
			
cmdclose:		db	0x03
				dw	C_NETCLOSE
clsocket:		db	0x0

cmdlookup:		db	16
				dw	C_NETHOSTIP
lookup_name:	ds	128

cmdrecv:		db	5
				dw	C_NETRECV	; recv
rsocket:		db	0x0			; socket
rsize:			dw	2048		; size
			
m4_rom_name:	db "M4 BOAR",0xC4		; D | 0x80
m4_rom_num:	db	0xFF
curPos:			dw	0
isEscapeCode:	db	0
EscapeCount:	db	0
EscapeBuf:		ds	255
buf:			ds	255	
defaulturl:		db "sdf.org",0
defaulturllength db 8

; Private receive storage must remain outside the M4 shared response buffer.
ReceiveBatchSize equ 64
ReceiveBatch: ds ReceiveBatchSize

ErrorContext: dw msgsenderror
msgconnecterror: db "Connection error: ",0
msgsessionerror: db "Session error: ",0
