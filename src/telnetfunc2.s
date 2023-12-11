			;  Telnet functionality, send, recieve and M4 Board Identification

start_telnet:	


            ld hl, msgtest
            call disptextz
			call drawline
            call Check_m4
			call loop_ip


telnet_session:
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
			jp		z,exit_close
wait_connect:
			ld		a,(ix)			; get socket status  (0 ==IDLE (OK), 1 == connect in progress, 2 == send in progress)
			cp		1				; connect in progress?
			jr		z,wait_connect
			cp		0
			jr		z,connect_ok
			call	disp_error	
			jp		exit_close
connect_ok:	ld		hl,msgconnect
			call	disptextz


mainloop:	ld		bc,1
			call	recv_noblock2
			
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
			
			ld		hl,sendtext
			ld		(hl),a
			
			
			
wait_send:	ld		a,(ix)
			cp		2			; send in progress?
			jr		z,wait_send	
			cp		0
			call	nz,disp_error	
			
			;xor		a
			;ld		(isEscapeCode),a
			
			ld		a,(hl)
			cp		0xD
			jr		nz, plain_text
			inc		hl
			ld		a,0xA
			ld		(hl),a
			
			ld		a,7
			ld		(cmdsend),a
			ld		a,2
			ld		(sendsize),a
			ld		hl,cmdsend
			call	sendcmd
			
			jp		mainloop
plain_text:
			ld		a,6
			ld		(cmdsend),a
			ld		a,1
			ld		(sendsize),a
			ld		hl,cmdsend
			call	sendcmd
			
			
			
			jp		mainloop




recv_noblock2:
			push 	af
			push 	bc
			push 	de
			push 	hl
			
			;ld	bc,2048		- to do empty entire receive buffer and use index
			
			ld		bc,1
			
			call 	recv
			cp		0xFF
			jp		z, exit_close	
			cp		3
			jp		z, exit_close
			xor		a
			cp		c
			jr		nz, got_msg2
			cp		b
			jr		nz, got_msg2
			pop 	hl
			pop 	de
			pop 	bc
			pop 	af
			ret

got_msg2:	
			; disp received msg
			push	iy
			pop		hl
			ld		de,0x6
			add		hl,de		; received text pointer
			ld		a,(hl)

			cp		CMD

            jr		nz,not_tel_cmd 
			call	negotiate
			
			jp		recvdone


not_tel_cmd:


			ld		b,a
            call printchar ; Handoff to ewenterm

			jp		recvdone

recvdone:	
			
			pop		hl
			pop		de
			pop		bc
			pop 	af
			ret
			


recv:		; connection still active
			ld		a,(ix)			; 
			cp		3				; socket status  (3 == remote closed connection)
			ret		z
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
			ld		hl,msgsenderror
			ld		bc,9
			call	disptext
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
			jp		loop_ip
			ret


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




msgconnclosed:	db	10,13,"Remote closed connection.",10,13,0
msgsenderror:	db	10,13,"ERROR: ",0
msgconnect:		db	10,13,"Connected.",10,13,0
msgserverip:	db	10,13,"Input server name or IP (:PORT or default to 23):",10,13,0
msgnom4:		db	"No M4 board found, bad luck :/",10,13,0
msgfoundm4:		db	"M4 Board installed",10,13,0
msgverfail:		db	", you need v1.1.0 or higher.",10,13,0
msgok:			db  ", OK.",10,13,0
msgconnecting:	db	10,13, "Connecting to IP ",0
msgport:		db  " port ",0
msgresolve:		db	10,13, "Resolving: ",0
msgfail:		db 	", failed!", 10, 13, 0
msgtitle:		db	"CPC telnet client v101 beta  Duke 2018",10,13,0
msgtest:        db "EwenM4 2023 v1.0 - Based on Ewenterm (1991) and M4 telnet (2018)",10,13,0
msgtitle2:		db  "================================================================",10,13,0
msguserabort:	db	10,13,"User aborted (ESC)", 10, 13,0
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