
#  M4EWEN/ EWENM4

## An ANSI Telnet client for the Amstrad CPC with M4 Board

*Built for time travel to 1985.*

Based on Ewenterm (https://ewen.mcneill.gen.nz/programs/cpc/ewenterm/) 1991
and Duke's M4 telnet Example (https://github.com/M4Duke/M4examples/blob/master/telnet.s) 2018

- Assembles with RASM (www.roudoudou.com/rasm)
- Tested with CPCEMU (https://www.cpc-emu.org/) and a 464, a 664 and a 6128.
- Also tested by the good people on cpcwiki.
- M4 board information here: (https://www.spinpoint.org/2019/11/19/m4-board-guides/)


## Usage
Copy EWEN.BAS, M4EWEN.BIN and CHARSET.BIN to the sdcard of the M4 board.

on the cpc: 

*** 
run"ewen 

***

From here type in a domain:port or ip:port.

All keypresses will go to the remote host, but for SHIFT-TAB (Pause) and SHIFT-ESC (Disconnect)

For places to telnet to visit: https://www.telnetbbsguide.com/ and https://www.mudconnect.com/cgi-bin/search.cgi?mode=mobile_biglist

This is naturally a very restricted telnet client, but that is part of its appeal!

Few places to start with.

- telehack.com 
    - Commands to try: `cat vttest.vt, phoon, rain, starwars, clock`.
- amstrad.simulant.uk:464
- ciaamigabbs.dynu.net:6400
- godwars.net:2250
- horizons.jpl.nasa.gov:6775 (use command `tty 24,80` to set screen)


### todo/ideas:
- Fix exit code. not nice right now.
- Telnet negotation non-existent.
- Allow the |TERM RSX to accept a domain/IP. Then build a BASIC menu of known working servers. or do this in assembly.
    - Or pull a webpage with up to date servers?
- Add a few more ANSI Control codes. Be nice to find a test server of some kind.
- Maybe do something to show colour? I think Honeyview used mode 1 for more colours and halved the character width.


**Fergus Leen November 2023**


