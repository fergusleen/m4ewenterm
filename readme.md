
#  M4EWEN

## An ANSI Telnet client for the Amstrad CPC with M4 Board

*Built for time travel to 1985.*

Based on Ewenterm (https://ewen.mcneill.gen.nz/programs/cpc/ewenterm/) 1991
and Duke's M4 telnet Example (https://github.com/M4Duke/M4examples/blob/master/telnet.s) 2018

- Assembles with RASM (www.roudoudou.com/rasm)
- Tested with CPCEMU (https://www.cpc-emu.org/).
- Also tested by the good people on cpcwiki.
- M4 board information here: (https://www.spinpoint.org/2019/11/19/m4-board-guides/)
- CPCWIKI Thread here: (https://www.cpcwiki.eu/forum/amstrad-cpc-hardware/ansi-telnet-for-the-m4-board/)

A version for the USIFAC 2 is also available on ikonsgr's Dropbox (Connect to BBS.zip) https://www.dropbox.com/sh/ezzga2dppm6jlm7/AACwFC_rv2QatWh_ndKc9fhma?dl=0


## Usage
Copy EWEN.BAS, M4EWEN.BIN and CHARSET.BIN to the sdcard of the M4 board.

on the cpc: 

*** 
run"ewen 

***

From here type in a domain:port or ip:port.

All keypresses will go to the remote host, but for SHIFT-TAB (Pause) and SHIFT-ESC (Disconnect). 

This is naturally a very restricted telnet client, but that is part of its appeal.

Few places to start with.

- telehack.com 
    - Commands to try: `cat vttest.vt, phoon, rain, starwars, clock`.
- amstrad.simulant.uk:464
- ciaamigabbs.dynu.net:6400
- godwars.net:2250
- horizons.jpl.nasa.gov:6775
- sdf.org


### todo/ideas:
- Telnet negotation could be expanded. A  SHOW OPTIONS function, which prints telnet commands as they arrive, is in the code but has been commented out as it can cause some display issues.
- Allow the |TERM RSX to accept a domain/IP. Then build a BASIC menu of known working servers. There is commented out code to display a default URL.  Not stable yet.
    - Pull a webpage with up to date servers?
- Add a few more ANSI Control codes. Could do animation?
- Maybe do something to show colour? I think it's possible to use mode 1 for more colours and half the character width.

 
If this is useful to you, please consider buying me a coffee. Coffee motivates :)

<a href="https://www.buymeacoffee.com/fleen" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/yellow_img.png" alt="Buy Me A Coffee"></a>


**F Leen November 2023**


