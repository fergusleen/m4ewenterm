PRINT "DATA AND MISC ROUTINES"

	

;----------------------------------------
;
;	DATA AREA
;
;	All data for the Terminal
;	Program is stored here
;
;----------------------------------------


ESC_key	ds	1		; 1 db to store current ESC setting
COPY_key	ds	1		; 1 db to store current COPY setting
CLR_key	ds	1		; 1 db to store current CLR setting
expansion_token
	db	0			; Two dbs for storage of
char_position
	db	0			; Macro temporary buffer
LDestDel	ds	1
RDestDel	ds	1

INK0		ds	2		; Save the ink colours
INK1		ds	2
SetupMessage	db	13,"Setup mode for Ewen-Term   ",0
dwWrapMessage
;		db	"Do you want dw wrap on ? ",0
		db	"dw Wrap?",0
RemoteEchoMessage
;		db	"Do you want remote echo on ? ",0
		db	"Remote Echo?",0
LocalEchoMessage
;		db	"Do you want local echo on ? ",0
		db	"Local Echo?",0
LocalDestDelMessage
;		db	"Do you want local destructive delete on ? ",0
		db	"(L) DEST DEL?",0
LocalAddLFMessage
;		db	"Do you want local ADD LF TO CR on ? ",0
		db	"(L) ADD LF?",0
LocalTabExpandMessage
;		db	"Do you want local tab expand on ? ",0
		db	"(L) TAB EXPAND?",0
RemoteDestDelMessage
;		db	"Do you want remote destructive delete on ? ",0
		db	"(R) DEST DEL?",0
RemoteAddLFMessage
;		db	"Do you want remote ADD LF TO CR on ? ",0
		db	"(R) ADD LF?",0
RemoteTabExpandMessage
;		db	"Do you want remote tab expand on ? ",0
		db	"(R) TAB EXPAND?",0
Yes		db	"Yes",13,10,0
No		db	"No",13,10,0
Dat1		db	0
Dat2		db	0
Cursor_Pos	dw	0		; Cursor save position;default 0,0

ScreenOffset	dw	0		; Offset from #C000 to start of screen

Romstate	db	0

HaveLoaded	db	0	; To show that a value has been put in
				; for Ansi emualtor

AnsiWasFirst	db	0	; Holds first character of Ansi sequence

NumberBuffer
	ds	20		; Buffer for numbers in Ansi

NumberPos	dw	NumberBuffer	; Address within buffer

CharacterNo	db	0	; db within Ansi sequence 0=first,255=other

CursorBlock	ds	9	; Block for cursor event

CursorCount	db	0	; 1/50ths of a second since last change

FastBlock	ds	2		; Buffering blocks
TickBlock	ds	7

backcolour	db	0
forecolour	db	7
namelength	db	0		; For Capture file
filename	ds	20		; Enough for ANY file name!
fontset	db	0		; Ansi font setup
JSW_FF		db	0		; db value to turn on/off FF routine
JSW_LF		db	0		; db value to turn on/off LF routine

bottom

length		EQU	bottom-top


	PRINT	"EWEN-TERM 22a statistics"
	PRINT	"  Begins",{hex}Top
	PRINT	"  Ends   ", {hex}Bottom
	PRINT	"  Length ",{hex}Length



CurrentLow	EQU	Bottom % #100
ToNextPage	EQU	#100 - CurrentLow
	ds	ToNextPage
LocalTrans
	DB	#00,#01,#02,#03,#04,#05,#06,#07,#08,#09,#0A,#0b,#0C,#0D,#0E,#0F
	DB	#10,#11,#12,#13,#14,#15,#16,#17,#18,#19,#1A,#1B,#1C,#1D,#1E,#1F
	DB	#20,#21,#22,#23,#24,#25,#26,#27,#28,#29,#2A,#2B,#2C,#2D,#2E,#2F
	DB	#30,#31,#32,#33,#34,#35,#36,#37,#38,#39,#3A,#3B,#3C,#3D,#3E,#3F
	DB	#40,#41,#42,#43,#44,#45,#46,#47,#48,#49,#4A,#4B,#4C,#4D,#4E,#4F
	DB	#50,#51,#52,#53,#54,#55,#56,#57,#58,#59,#5A,#5B,#5C,#5D,#5E,#5F
	DB	#60,#61,#62,#63,#64,#65,#66,#67,#68,#69,#6A,#6B,#6C,#6D,#6E,#6F
	DB	#70,#71,#72,#73,#74,#75,#76,#77,#78,#79,#7A,#7B,#7C,#7D,#7E,#08
	DB	#80,#81,#82,#83,#84,#85,#86,#87,#88,#89,#8A,#8B,#8C,#8D,#8E,#8F
	DB	#90,#91,#92,#93,#94,#95,#96,#97,#98,#99,#9A,#9B,#9C,#9D,#9E,#9F
	DB	#A0,#A1,#A2,#A3,#A4,#A5,#A6,#A7,#A8,#A9,#AA,#AB,#AC,#AD,#AE,#AF
	DB	#B0,#B1,#B2,#B3,#B4,#B5,#B6,#B7,#B8,#B9,#BA,#BB,#BC,#BD,#BE,#BF
	DB	#C0,#C1,#C2,#C3,#C4,#C5,#C6,#C7,#C8,#C9,#CA,#CB,#CC,#CD,#CE,#CF
	DB	#D0,#D1,#D2,#D3,#D4,#D5,#D6,#D7,#D8,#D9,#DA,#DB,#DC,#DD,#DE,#DF
	DB	#E0,#E1,#E2,#E3,#E4,#E5,#E6,#E7,#E8,#E9,#EA,#EB,#EC,#ED,#EE,#EF
	DB	#F0,#F1,#F2,#F3,#F4,#F5,#F6,#F7,#F8,#F9,#FA,#FB,#FC,#FD,#FE,#FF
HighLocalTrans	EQU	LocalTrans/#100

RemoteTrans
	DB	#00,#01,#02,#03,#04,#05,#06,#07,#08,#09,#0A,#0B,#0C,#0D,#0E,#0F
	DB	#10,#11,#12,#13,#14,#15,#16,#17,#18,#19,#1A,#1B,#1C,#1D,#1E,#1F
	DB	#20,#21,#22,#23,#24,#25,#26,#27,#28,#29,#2A,#2B,#2C,#2D,#2E,#2F
	DB	#30,#31,#32,#33,#34,#35,#36,#37,#38,#39,#3A,#3B,#3C,#3D,#3E,#3F
	DB	#40,#41,#42,#43,#44,#45,#46,#47,#48,#49,#4A,#4B,#4C,#4D,#4E,#4F
	DB	#50,#51,#52,#53,#54,#55,#56,#57,#58,#59,#5A,#5B,#5C,#5D,#5E,#5F
	DB	#60,#61,#62,#63,#64,#65,#66,#67,#68,#69,#6A,#6B,#6C,#6D,#6E,#6F
	DB	#70,#71,#72,#73,#74,#75,#76,#77,#78,#79,#7A,#7B,#7C,#7D,#7E,#08
	DB	#80,#81,#82,#83,#84,#85,#86,#87,#88,#89,#8A,#8B,#8C,#8D,#8E,#8F
	DB	#90,#91,#92,#93,#94,#95,#96,#97,#98,#99,#9A,#9B,#9C,#9D,#9E,#9F
	DB	#A0,#A1,#A2,#A3,#A4,#A5,#A6,#A7,#A8,#A9,#AA,#AB,#AC,#AD,#AE,#AF
	DB	#B0,#B1,#B2,#B3,#B4,#B5,#B6,#B7,#B8,#B9,#BA,#BB,#BC,#BD,#BE,#BF
	DB	#C0,#C1,#C2,#C3,#C4,#C5,#C6,#C7,#C8,#C9,#CA,#CB,#CC,#CD,#CE,#CF
	DB	#D0,#D1,#D2,#D3,#D4,#D5,#D6,#D7,#D8,#D9,#DA,#DB,#DC,#DD,#DE,#DF
	DB	#E0,#E1,#E2,#E3,#E4,#E5,#E6,#E7,#E8,#E9,#EA,#EB,#EC,#ED,#EE,#EF
	DB	#F0,#F1,#F2,#F3,#F4,#F5,#F6,#F7,#F8,#F9,#FA,#FB,#FC,#FD,#FE,#FF
HighRemoteTrans	EQU	RemoteTrans/#100


Character
	ds	8		; To buffer character to be printed	
CursorPosition
	dw	0		; Cursor position, default 0,0

CursorOn
	db	0		; Cursor on/off toggle value

Bottom2					; Realign on page, for above
CurrentLow2	EQU	Bottom2 MOD #100	; short block
ToNextPage2	EQU	#100 - CurrentLow2
	ds	ToNextPage2

Amstrad_Screen	EQU	#C000
ScreenAddress
	dw 	0*80+Amstrad_Screen
	dw	1*80+Amstrad_Screen
	dw	2*80+Amstrad_Screen
	dw	3*80+Amstrad_Screen
	dw	4*80+Amstrad_Screen
	dw	5*80+Amstrad_Screen
	dw	6*80+Amstrad_Screen
	dw	7*80+Amstrad_Screen
	dw	8*80+Amstrad_Screen
	dw	9*80+Amstrad_Screen
	dw	10*80+Amstrad_Screen
	dw	11*80+Amstrad_Screen
	dw	12*80+Amstrad_Screen
	dw	13*80+Amstrad_Screen
	dw	14*80+Amstrad_Screen
	dw	15*80+Amstrad_Screen
	dw	16*80+Amstrad_Screen
	dw	17*80+Amstrad_Screen
	dw	18*80+Amstrad_Screen
	dw	19*80+Amstrad_Screen
	dw	20*80+Amstrad_Screen
	dw	21*80+Amstrad_Screen
	dw	22*80+Amstrad_Screen
	dw	23*80+Amstrad_Screen
	dw	24*80+Amstrad_Screen
HighScreenAddress	EQU	ScreenAddress/#100

HereIam
HighHere	EQU	HereIam/#100
NextHighHere	EQU	HighHere + 1

Buffer		EQU	NextHighHere * #100

High_Buffer_Out	EQU	NextHighHere + 4
OutBuffer	EQU	High_Buffer_Out * #100

;
;	Used to mark the last address
;
LastAddress
TotalLength	EQU	LastAddress - Top
TablesLength	EQU	LastAddress - Bottom

	PRINT	"  Tables = ",{hex}TablesLength
	PRINT	"---------------"
	PRINT	"  Total  = ",{hex}TotalLength
	PRINT	"---------------"
	PRINT	"  Final  = ",{hex}LastAddress
	PRINT	"---------------"
	PRINT	" "
	PRINT	"Screen Address", {hex}ScreenAddress
;	PRINT	"Address Buffer",{hex}AddressBuffer
	PRINT	"Out Buffer ",{hex}OutBuffer
	PRINT   "In Buffer  ",{hex}Buffer
