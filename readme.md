
#  M4EWEN/ EWENM4

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
- Telnet negotation could be expanded. A  SHOW OPTIONS function, which lists telnet functions as they arrive is in the code but has been commented out as it can cause some display issues.
- Allow the |TERM RSX to accept a domain/IP. Then build a BASIC menu of known working servers. Some work in the code to display a default URL. Not stable yet.
    - Or pull a webpage with up to date servers?
- Add a few more ANSI Control codes. Could do animation?
- Maybe do something to show colour? I think it's possible to use mode 1 for more colours and half the character width.

 
If this is useful to you, please consider buying me a coffee! It's pretty good encouragement to add more.
<script type="text/javascript" src="https://cdnjs.buymeacoffee.com/1.0.0/button.prod.min.js" data-name="bmc-button" data-slug="fleen" data-color="#FFDD00" data-emoji="" data-font="Cookie" data-text="Buy me a coffee" data-outline-color="#000000" data-font-color="#000000" data-coffee-color="#ffffff" ></script>

**F Leen November 2023**


