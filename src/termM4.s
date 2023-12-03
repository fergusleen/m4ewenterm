; Assembled with Rasm for Z80
; Converting from Maxam to Rasm

; An ANSI Telnet client for the Amstrad CPC with M4 Board
; Based on Ewenterm (https://ewen.mcneill.gen.nz/programs/cpc/ewenterm/) 1990
; and Duke's M4 Examples (https://github.com/M4Duke/M4examples/blob/master/telnet.s) 2018
; F Leen November 2023

;LIMIT #9700            ; Finish before #9700 or ELSE!


true        equ 1
false       equ 0
on          equ true
off         equ false
screen_depth    equ 24


colour      equ true


;See historydoc file for history of program

    org #7000 ; Start assembling at #7000, Charset loaded at runtime now
    nolist

; Constants and firmware routines

Characterset  equ #6800
HCharSet      equ #0068   ; Rasm uses a full 16-bit format, even if the high byte is 00

top

;***    Keyboard
KM_READ_KEY             equ #BB1B
KM_WAIT_KEY		EQU	#BB18
KM_GET_EXPAND		EQU	#BB12
KM_TEST_KEY		EQU	#BB1E
KM_READ_CHAR		EQU	#BB09
KM_WAIT_CHAR		EQU	#BB06
KM_GET_TRANSLATE        EQU	#BB2A
KM_SET_TRANSLATE	EQU	#BB27
;***	Text Screen
TXT_OUTPUT		EQU	#BB5A
TXT_WR_CHAR		EQU	#BB5D
TXT_WIN_ENABLE		EQU	#BB66
TXT_GET_WINDOW		EQU	#BB69
TXT_SET_COLUMN		EQU	#BB6F
TXT_SET_ROW		EQU	#BB72
TXT_SET_CURSOR		EQU	#BB75
TXT_GET_CURSOR		EQU	#BB78
TXT_CUR_ON		EQU	#BB81
TXT_CUR_OFF		EQU	#BB84
TXT_GET_MATRIX		EQU	#BBA5
;***	Screen, General
SCR_SET_OFFSET		EQU	#BC05
SCR_SET_MODE		EQU	#BC0E
SCR_GET_MODE		EQU	#BC11
SCR_CLEAR		EQU	#BC14
SCR_SET_INK		EQU	#BC32
SCR_GET_INK		EQU	#BC35
SCR_HW_ROLL		EQU	#BC4D
;***	Machine pack
MC_WAIT_FLYBACK		EQU	#BD19
MC_PRINT_CHAR		EQU	#BD2B
MC_BUSY_PRINTER		EQU	#BD2E
;***	Cassette/Disc
CAS_OUT_OPEN		EQU	#BC8C
CAS_OUT_CLOSE		EQU	#BC8F
CAS_OUT_CHAR		EQU	#BC95
;***	Kernel - High
KL_U_ROM_DISABLE	EQU	#B903
KL_ROM_RESTORE		EQU	#B90C
;***	Kernal - Normal
KL_LOG_EXT		EQU	#BCD1
KL_FIND_COMMAND		EQU	#BCD4
KL_NEW_FRAME_FLY	EQU	#BCD7
KL_DEL_FRAME_FLY	EQU	#BCDD
KL_NEW_FAST_TICKER	EQU	#BCE0
KL_DEL_FAST_TICKER	EQU	#BCE6
KL_DISARM_EVENT		EQU	#BD0A

DATAPORT		equ 0xFE00
ACKPORT			equ 0xFC00			

; m4 commands used
C_NETSOCKET		equ 0x4331
C_NETCONNECT	equ 0x4332
C_NETCLOSE		equ 0x4333
C_NETSEND		equ 0x4334
C_NETRECV		equ 0x4335
C_NETHOSTIP		equ 0x4336


scr_reset		equ	0xBC0E
scr_set_border	equ	0xBC38
kl_rom_select	equ 0xb90f

; telnet negotiation codes
DO 				equ 0xfd
WONT 			equ 0xfc
WILL 			equ 0xfb
DONT 			equ 0xfe
CMD 			equ 0xff
CMD_ECHO 		equ 1
CMD_WINDOW_SIZE equ 31

; Define RSX command table and data area
login
    ld bc, command_table
    ld hl, rsx_data_area
    call KL_LOG_EXT
    ret

command_table
    dw rsx_names
    jp term
;    jp setup
    ;  rest of the commands 

rsx_names
    str 'TERM'       ; Terminal program
;    str	'SETUP'			; Configuration program
    db 0 

rsx_data_area
    ds 4               ; 4 bytes for RSX workspace

    include "mainline.s"
    include "ansiterm.s"
    include "screen.s"
    include "urlmenu.s"
    include "telnetfunc2.s"
    include "data.s"


SAVE 'EWENM4.BIN',#7000,$-#7000,AMSDOS


