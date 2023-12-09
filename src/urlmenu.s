            ; Code for Domain / IP entry and DNS lookup

			; ask for server / ip
loop_ip:

            call drawline
			ld		hl,msgserverip
			call	disptextz
			call	get_server
			cp		0
			jr		nz, loop_ip
			
			ld		hl,msgconnecting
			call	disptextz
			
			ld		hl,ip_addr
			call	disp_ip
			
			ld		hl,msgport
			call	disptextz
			
			ld		hl,(port)
			call	disp_port
			call	crlf
			call	telnet_session
			jp		loop_ip
			


print_lownib:			
			and		0xF			; keep lower nibble
			add		48			; 0 + x = neric ascii
			jp		printchar
			
get_server:	
			ld		hl,buf
			call	get_textinput
			
			;cp		0xFC			; ESC?
			;ret		z
			xor		a
			cp		c
			jr		z, get_server
		
			; check if any none neric chars
			
			ld		b,c
			ld		hl,buf
check_neric:
			ld		a,(hl)
			cp		59				; bigger than ':' ?
			jr		nc,dolookup
			inc		hl
			djnz	check_neric
			jp		convert_ip
			
			; make dns lookup
dolookup:	
			; copy name to packet
			
			ld		hl,buf
			ld		de,lookup_name
			ld		b,0
copydns:	ld		a,(hl)
			cp		58
			jr		z,copydns_done
			cp		0
			jr		z,copydns_done
			ld		a,b
			ldi
			inc		a
			ld		b,a
			jr		copydns
copydns_done:
			push	hl
			xor		a
			ld		(de),a		; terminate with zero
			
			ld		hl,cmdlookup
			inc		b			
			inc		b
			inc		b
			ld		(hl),b		; set  size
			
			; disp servername
			
			ld		hl,msgresolve
			call	disptextz
			ld		hl,lookup_name
			call	disptextz
			
			; do the lookup
			call	dnslookup
			pop		hl
			cp		0
			jr		z, lookup_ok
			
			ld		hl,msgfail
			call	disptextz
			ld		a,1
				

		
			ret
			
lookup_ok:	push	hl			; contains port "offset"
			ld		hl,msgok
			call	disptextz
			
			; copy IP from socket 0 info
			ld		hl,(0xFF06)
			ld		de,4
			add		hl,de
			ld		de,ip_addr
			ldi
			ldi
			ldi
			ldi
			pop		hl
			jr		check_port
			; convert ascii IP to binary, no checking for non decimal chars format must be x.x.x.x
convert_ip:			
			ld		hl,buf	
			call	ascii2dec
			ld		(ip_addr+3),a
			call	ascii2dec
			ld		(ip_addr+2),a
			call	ascii2dec
			ld		(ip_addr+1),a
			call	ascii2dec
			ld		(ip_addr),a
			dec		hl
check_port:	ld		a,(hl)
			cp		0x3A		; any ':' for port number ?
			jr		nz, no_port
			
			push	hl
			pop		ix
			call	port2dec
			
			jr		got_port
			
no_port:	ld		hl,23
got_port:	
			ld		(port),hl
			xor		a
			ret

			
dnslookup:	
            call romen
            ld		hl,(0xFF02)	; get response buffer address
			push	hl
			pop		iy
			
			ld		hl,(0xFF06)	; get sock info
			push	hl
			pop		ix		; ix ptr to current socket status
			

			ld		hl,cmdlookup
			call	sendcmd
			ld		a,(iy+3)
			cp		1
			jr		z,wait_lookup
			ld		a,1
			ret
			
wait_lookup:
			ld	a,(ix+0)
			cp	5			; ip lookup in progress
			jr	z, wait_lookup
			ret

			;
			; Get input text line.
			;
			; in
			; hl = dest buf
			; return
			; bc = out size
get_textinput:		
			ld	bc,0
			;call	txt_cur_on	
inputloop:
			
re:			call	mc_wait_flyback
			call	km_read_char
			jr		nc,re

			cp		0x7F
			jr		nz, not_delkey
            call printchar
			ld		a,c
			cp		0
			jr		z, inputloop

			; push	hl
			; push	bc
			; ;call	txt_get_cursor
			; dec		h
			; push	hl
			; ;call	txt_set_cursor
			; ;ld		a,32
			; call	printchar
			; pop		hl
			; ;call	txt_set_cursor
			; pop		bc
			; pop		hl
			 dec		hl
			 dec		bc
			jr		inputloop
not_delkey:	
			cp		13
			jr		z, terminate
			cp		0xFC
			ret		z
			cp 32              ; Check if the pressed key is space
			ret z
			; ;jr nz, not_space   ; Jump if not space ; leave the out for now, likely to need something at the top of the screen.
			; call togglePrintTelCmd
			; ret
not_space:
			cp		0x7e
			jr		nc, inputloop
			ld		(hl),a
			inc		hl
			inc		bc
			push	hl
			push	bc
			call	printchar
			;call	txt_get_cursor
			;push	hl
			;ld		a,32
			;call	printchar
			;pop	hl
			;call	txt_set_cursor
			pop		bc
			pop		hl
			jp		inputloop
terminate:	ld		(hl),0
			ret


togglePrintTelCmd:
    ld a, (printTelCmdFlag)
    xor 1              ; Toggle the flag
    ld (printTelCmdFlag), a
    call printToggleMsg
    ret

printToggleMsg:
    push hl          ; Save the current value of HL
    ld a, (printTelCmdFlag)
    ld hl, msgPrintTelOff
    jr z, skipToggleMsgOn
    ld hl, msgPrintTelOn
skipToggleMsgOn:
    call disptextz
    pop hl           ; Restore the original value of HL
    ret

			;
			; Get input text line, accept only neric and .
			;
			; in
			; hl = dest buf
			; return
			; bc = out size
get_textinput_ip:		
			ld	bc,0
			;call	txt_cur_on	
inputloop2:
			
re2:		call	mc_wait_flyback
			call	km_read_char
			jr		nc,re2

			cp		0x7F
			jr		nz, not_delkey2
			ld		a,c
			cp		0
			jr		z, inputloop2
			push	hl
			push	bc
			;call	txt_get_cursor
			dec	h
			push	hl
			;call	txt_set_cursor
			ld		a,32
			call	printchar
			pop	hl
			;call	txt_set_cursor
			pop		bc
			pop		hl
			dec		hl
			dec		bc
			jr		inputloop2
not_delkey2:	
			cp		13
			jr		z, enterkey2
			cp		0xFC
			ret		z
			cp		46				; less than '.'
			jr		c, inputloop2
			cp		59				; bigger than ':' ?
			jr		nc, inputloop2
			
			
			ld		(hl),a
			inc		hl
			inc		bc
			push	hl
			push	bc
			call	printchar
			;call	txt_get_cursor
			;push	hl
			;ld		a,32
			;call	printchar
			;pop	hl
			;call	txt_set_cursor
			pop		bc
			pop		hl
			jp		inputloop2
enterkey2:	ld		(hl),0
			ret
			


crlf:		
            push af
            ld		a,10
			call	printchar
			ld		a,13
			call	printchar
            pop af 
            ret

			
			; HL = point to IP addr
			
disp_ip:	ld		bc,3
			add		hl,bc
			ld		b,3
disp_ip_loop:
			push	hl
			push	bc
			call	dispdec
			pop		bc
			pop		hl
			dec		hl
			ld		a,0x2e
			call	printchar
			djnz	disp_ip_loop
			
			jp		dispdec	; last digit
			
			
dispdec:	ld		e,0
			ld		a,(hl)
			ld		l,a
			ld		h,0
			ld		bc,-100
			call	n1
			cp		'0'
			jr		nz,notlead0
			ld		e,1
notlead0:	call	nz,printchar
			ld		c,-10
			call	n1
			cp		'0'
			jr		z, lead0_2
			call	printchar
lead0_2_cont:	
			ld		c,b
			call	n1
			jp		printchar
			
n1:			ld		a,'0'-1
n2:			inc		a
			add		hl,bc
			jr		c,n2
			sbc		hl,bc
			ret
lead0_2:
			ld		d,a
			xor		a
			cp		e
			ld		a,d
			call	z,printchar
			jr		lead0_2_cont
						
			; ix = points to :portnumber
			; hl = return 16 bit number
			
port2dec:
count_digits:
			inc		ix
			ld		a,(ix)
			cp		0
			jr		nz,count_digits
			dec		ix
			ld		a,(ix)
			cp		0x3A
			ret		z
			sub		48
			ld		l,a			; *1
			ld		h,0
			
			
			dec		ix
			ld		a,(ix)
			cp		0x3A
			ret		z
			sub		48

			push	hl
			ld  	e,a
			ld		d,0
			ld 		bc,10
			call	mul16		; *10
			pop		de
			add		hl,de		
			dec		ix
			ld		a,(ix)
			cp		0x3A
			ret		z
			sub		48
			
			push	hl
			ld  	e,a
			ld		d,0
			ld 		bc,100
			call	mul16		; *100
			pop		de
			add		hl,de		
			dec		ix
			ld		a,(ix)
			cp		0x3A
			ret		z
			sub		48
			
			push	hl
			ld  	e,a
			ld		d,0
			ld 		bc,1000
			call	mul16		; *1000
			pop		de
			add		hl,de		
			dec		ix
			ld		a,(ix)
			cp		0x3A
			ret		z
			sub		48
			
			push	hl
			ld  	e,a
			ld		d,0
			ld 		bc,10000
			call	mul16		; *10000
			pop		de
			add		hl,de		
			ret
						
ascii2dec:	ld		d,0
loop2e:		ld		a,(hl)
			cp		0
			jr		z,found2e
			cp		0x3A		; ':' port seperator ?
 			jr		z,found2e
			
			cp		0x2e
			jr		z,found2e
			; convert to decimal
			cp		0x41	; a ?
			jr		nc,less_than_a
			sub		0x30	; - '0'
			jr		next_dec
less_than_a:	
			sub		0x37	; - ('A'-10)
next_dec:		
			ld		(hl),a
			inc		hl
			inc		d
			dec		bc
			xor		a
			cp		c
			ret		z
			jr		loop2e
found2e:
			push	hl
			call	dec2bin
			pop		hl
			inc		hl
			ret
dec2bin:	dec		hl
			ld		a,(hl)
			dec		hl
			dec		d
			ret		z
			ld		b,(hl)
			inc		b
			dec		b
			jr		z,skipmul10
mul10:		add		10
			djnz	mul10
skipmul10:	dec		d
			ret		z
			dec		hl
			ld		b,(hl)
			inc		b
			dec		b
			ret		z
mul100:		add		100
			djnz	mul100
			ret
			
			; BC*DE

mul16:		ld	hl,0
			ld	a,16
mul16Loop:	add	hl,hl
			rl	e
			rl	d
			jp	nc,nomul16
			add	hl,bc
			jp	nc,nomul16
			inc	de
nomul16:
			dec	a
			jp	nz,mul16Loop
			ret

			
disp_port:
			ld		bc,-10000
			call	n16_1
			cp		48
			jr		nz,not16_lead0
			ld		bc,-1000
			call	n16_1
			cp		48
			jr		nz,not16_lead1
			ld		bc,-100
			call	n16_1
			cp		48
			jr		nz,not16_lead2
			ld		bc,-10
			call	n16_1
			cp		48
			jr		nz, not16_lead3
			jr		not16_lead4
	
not16_lead0:
			call	printchar
			ld		bc,-1000
			call	n16_1
not16_lead1:
			call	printchar
			ld		bc,-100
			call	n16_1
not16_lead2:
			call	printchar
			ld		c,-10
			call	n16_1
not16_lead3:
			call	printchar
not16_lead4:
			ld		c,b
			call	n16_1
			call	printchar
			ret
n16_1:
			ld		a,'0'-1
n16_2:
			inc		a
			add		hl,bc
			jr		c,n16_2
			sbc		hl,bc

			;ld		(de),a
			;inc	de
			
			ret			


            