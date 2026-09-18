
#  M4EWEN - A VT100 TERMINAL FOR THE AMSTRAD CPC

>**UPDATE 2026: Now VT100 compatible and optimised for speed. Works with vi.**

As far as I know, a VT100 terminal was never built for the CPC.
----
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

While the TCP connection is pending, press **Escape** (or **Shift-Escape**) to
close the pending socket and return to the destination menu. The connecting
message shows `(ESC cancels)`. This applies to the connection wait after DNS
resolution, not to the M4 DNS lookup itself.

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
- Need to decide on the name!

 
If this is useful to you, please consider buying me a coffee. Coffee motivates :)

<a href="https://www.buymeacoffee.com/fleen" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/yellow_img.png" alt="Buy Me A Coffee"></a>


**F Leen November 2023**



## VT100 foundation (work in progress) 2026

The terminal now uses an 80-column, 24-row display with a streaming escape
parser. The parser, full-screen editing, character-set, and Telnet milestones are implemented. This remains a practical 80x24 VT100 subset rather than complete hardware emulation.

Implemented:

- Bounded CSI parameters, including omitted/zero defaults and clamped cursor moves.
- Cursor movement (`A/B/C/D`, `H/f`) and display/line erasure (`J/K`). Erasure
  includes the cursor cell, preserves its position, and uses the normal background.
- Delayed right-margin wrapping and DEC autowrap mode (`CSI ? 7 h/l`).
- Separate CR and LF behaviour, backspace, fixed eight-column tabs, and ignored DEL.
- Full-screen scrolling across 24 rows; the CPC's extra physical row stays blank.
- Safe consumption of unsupported ESC/CSI commands and control strings,
  cancellation with CAN/SUB, and restart on ESC.
- Existing text attributes and ANSI `CSI s/u` position save/restore remain available.
- Scroll margins (`CSI top;bottom r`), index (`ESC D`), next line (`ESC E`),
  and reverse index (`ESC M`). Headers/footers outside a region stay fixed.
- Origin-relative addressing (`CSI ? 6 h/l`), including cursor movement limits.
- DEC cursor save/restore (`ESC 7/8`) for position, current attributes, origin,
  autowrap, pending wrap, G0/G1 character-set designations, and active character set.
- Normal arrow keys (`ESC [ A/B/D/C`) and application arrow keys
  (`ESC O A/B/D/C`), selected by `CSI ? 1 h/l` for Up/Down/Left/Right.
  Each key is sent as a single M4 packet. Enter retains Telnet CR/LF encoding.

- DEC special graphics via `ESC ( 0` / `ESC ) 0`, ASCII via `ESC ( B` /
  `ESC ) B`, and UK designation `A`; SI/SO select G0/G1. Graphics include
  connecting lines, corners, junctions, scanlines, and mathematical symbols.
  Control pictures use compact 8x8 glyphs. Existing CP437 BBS glyphs stay intact.
- Ready (`CSI 5 n`), cursor-position (`CSI 6 n`, respecting origin mode), and
  device-attributes (`CSI c`, `CSI 0 c`, `ESC Z`) replies. DA reports `CSI ? 1 ; 0 c`.
- Streaming Telnet negotiation, including fragmented commands, escaped IAC,
  bounded subnegotiation, and duplicate/withdrawn option handling. The client
  answers TERMINAL-TYPE SEND with **VT100** after accepting DO TERMINAL-TYPE,
  and advertises **80x24** after accepting NAWS. Remote ECHO and suppress-go-ahead
  are supported; unsupported options are refused.


### Automated assembly tests

```sh
./build.sh
python3 -m venv /tmp/m4term-tests
/tmp/m4term-tests/bin/pip install -r tests/requirements.txt
/tmp/m4term-tests/bin/python tests/test_terminal.py
```

The tests run the built binary in a Z80 emulator and inspect cursor state and
screen RAM. CPC firmware calls are stubbed, so these do not replace testing the
real display, ROM banking, cursor interrupt timing, or M4 network interface.

### Repeatable CPCEMU / CPC visual test


```sh
python3 tools/vt100_probe.py --bind 0.0.0.0 --port 2324 --fragment 1
```

In M4TERM, select a manual destination and enter the hosts's LAN IP with `:2324`.
Each page states the expected result. Press **Space** for the next page, **R** to
repeat, or **Q** to close the connection. Stop the server with Ctrl-C.

Pages 1–5 check cursor bounds, erasure, delayed wrapping/CR/LF/tabs,
24-row scrolling, and malformed/unsupported sequences. Pages 6–8 check scrolling
regions, reverse scrolling, and origin mode plus saved cursor attributes.
Pages 9–10 check normal/application arrow keys: press each arrow and verify
that the server reports **PASS** with the correct direction. Page 11 draws two
identical boxes using G0/G1. Page 12 expects three PASS reports (ready, VT100 ID,
cursor 7;13). Page 13 expects PASS VT100 and PASS 80x24; it also works when repeated.

`--fragment 1` sends one byte at a time to exercise sequences split between receives. Pages 1–12 send no Telnet option negotiation; page 13 explicitly
exercises it.

Protocol reference: [DEC VT100 User Guide, chapter 3](https://vt100.net/docs/vt100-ug/chapter3.html).

### Plain-text rendering optimisation

The renderer caches whether attributes or the selected character set require
buffered drawing. SGR, character-set selection, reset and DEC cursor restore
refresh this derived state. Plain glyphs use eight unrolled raster writes.

Compared with the preceding build, a Z80 benchmark of `PRINTCHAR` for `A`
dropped from 1,588 cycles to 1,455 with caching, then to 1,333 with unrolling
(about 16% fewer overall). A bold/underlined/inverse sample dropped from 2,932
to 2,852 cycles. Firmware is stubbed in these measurements; they do not measure
CPC/M4 wall-clock throughput. The binary remains 9,010 bytes excluding its
AMSDOS header because the additional code fits existing alignment padding.

The assembly tests compare cached rendering with forced buffered rendering
across style, colour, character-set, shift-in/out, save/restore and reset changes.
