"""Run the assembled renderer in a Z80 CPU; stub only CPC firmware calls.

Build first with ./build.sh. Run with Python plus z80==1.1.0 installed.
This checks screen RAM and cursor state, not a second parser implementation.
"""
from pathlib import Path
import unittest
import runpy
import z80

ROOT = Path(__file__).resolve().parents[1]
SYMS = {p[0]: int(p[1][1:], 16) for line in
        (ROOT / 'bin/rasmoutput.sym').read_text().splitlines()
        if len(p := line.split()) >= 2 and p[1].startswith('#')}


class Terminal:
    def __init__(self):
        self.cpu = z80.Z80Machine()
        self.mem = self.cpu.memory
        for filename, address in [('EWENM4.BIN', 0x7000), ('CHARSET.BIN', 0x6800)]:
            data = (ROOT / 'bin' / filename).read_bytes()
            assert sum(data[:67]) & 65535 == int.from_bytes(data[67:69], 'little')
            self.cpu.set_memory_block(address, data[128:])
        for address in [SYMS['ROMDIS'], SYMS['ROMEN'], 0xBC05, 0xBB5A,
                        0xBD19, 0xBC35, 0xBC32]:
            self.mem[address] = 0xC9
        self.hooks={}
        self.packets=[]
        self.cpu.set_breakpoint(SYMS['SENDCMD'])
        self.cpu.set_breakpoint(0x0100)
        self.call('ALLOFF')

    def call(self, name, a=0):
        m = self.cpu
        m.pc = SYMS[name]
        m.a = a
        m.sp = 0xB000
        self.mem[0xB000:0xB002] = b'\x00\x01'
        for _ in range(200):
            m.ticks_to_stop = 100000
            m.run()
            if m.pc in self.hooks:
                self.hooks[m.pc]()
                m.pc=int.from_bytes(self.mem[m.sp:m.sp+2],'little')
                m.sp+=2
            elif m.pc == SYMS['SENDCMD']:
                assert m.hl == SYMS['CMDSEND'], 'unexpected M4 command'
                size=int.from_bytes(self.mem[m.hl+4:m.hl+6],'little')
                assert self.mem[m.hl] == size+5
                self.packets.append(bytes(self.mem[m.hl+6:m.hl+6+size]))
                m.pc=int.from_bytes(self.mem[m.sp:m.sp+2],'little')
                m.sp+=2
            if m.pc == 0x0100:
                assert m.sp == 0xB002, 'unbalanced stack'
                return
        raise AssertionError(f'{name} failed to return, PC={m.pc:04x}')

    def feed(self, data):
        for byte in data:
            self.call('PRINTCHAR', byte)

    def feed_network(self, data):
        for byte in data:
            self.call('TELNETBYTE',byte)

    def value(self, name):
        return self.mem[SYMS[name]]

    @property
    def cursor(self):
        p = SYMS['CURSORPOSITION']
        return self.mem[p] + 1, self.mem[p+1] + 1

    def cell(self, row, column):
        p = SYMS['SCREENOFFSET']
        offset = int.from_bytes(self.mem[p:p+2], 'little')
        base = ((row-1)*80 + column-1 + offset) & 2047
        return bytes(self.mem[0xC000 + base + scan*2048] for scan in range(8))

    def glyph(self, char):
        return bytes(self.mem[0x6800 + ord(char) + scan*256] for scan in range(8))


class TerminalTests(unittest.TestCase):
    def setUp(self):
        self.t = Terminal()

    def test_position_defaults_and_clamping(self):
        for seq, expected in [(b'\x1b[10;20H', (10,20)), (b'\x1b[;H', (1,1)),
                              (b'\x1b[0;0H', (1,1)), (b'\x1b[9999;9999H', (24,80)),
                              (b'\x1b[0A\x1b[0D', (23,79)),
                              (b'\x1b[999B\x1b[999C', (24,80)),
                              (b'\x1b[999A\x1b[999D', (1,1))]:
            self.t.feed(seq)
            self.assertEqual(self.t.cursor, expected)

    def test_delayed_wrap_and_sgr(self):
        t=self.t
        t.feed(b'\x1b[5;80HX')
        self.assertEqual(t.cursor,(5,80))
        t.feed(b'\x1b[0mY')
        self.assertEqual(t.cursor,(6,2))
        self.assertEqual(t.cell(5,80),t.glyph('X'))
        self.assertEqual(t.cell(6,1),t.glyph('Y'))

    def test_cr_lf_bs_tab(self):
        t=self.t
        t.feed(b'\x1b[5;10H\n')
        self.assertEqual(t.cursor,(6,10))
        t.feed(b'\r')
        self.assertEqual(t.cursor,(6,1))
        t.feed(b'\t')
        self.assertEqual(t.cursor,(6,9))
        t.feed(b'\x1b[6;79H\t')
        self.assertEqual(t.cursor,(6,80))
        t.feed(b'X\bY')
        self.assertEqual(t.cursor,(6,80))
        self.assertEqual(t.cell(6,79),t.glyph('Y'))
        t.feed(b'\x1b[6;80HX\r\nZ')
        self.assertEqual(t.cursor,(7,2))

    def test_wrap_off_and_private_isolation(self):
        t=self.t
        t.feed(b'\x1b[?7l\x1b[2;80HAB')
        self.assertEqual(t.cursor,(2,80))
        self.assertEqual(t.cell(2,80),t.glyph('B'))
        t.feed(b'\x1b[?2J')
        self.assertEqual(t.cell(2,80),t.glyph('B'))
        t.feed(b'\x1b[?7hCD')
        self.assertEqual(t.cursor,(3,2))

    def test_erase_display_preserves_cursor(self):
        t=self.t
        t.feed(b'\x1b[2;2HX\x1b[3;3HY\x1b[2J')
        self.assertEqual(t.cursor,(3,4))
        self.assertEqual(t.cell(2,2),bytes(8))
        self.assertEqual(t.cell(3,3),bytes(8))
        t.feed(b'\x1b[HX\x1b[24;80HY\x1b[HZ\x1b[1G')
        t.feed(b'\x1b[1;1H\x1b[1J')
        self.assertEqual(t.cell(1,1),bytes(8))
        self.assertEqual(t.cell(24,80),t.glyph('Y'))
        t.feed(b'\x1b[24;80H\x1b[J')
        self.assertEqual(t.cell(24,80),bytes(8))
        self.assertEqual(t.cursor,(24,80))

    def test_erase_line_includes_cursor_and_ignores_inverse(self):
        t=self.t
        t.feed(b'ABCDE\x1b[1;3H\x1b[1K')
        self.assertEqual([t.cell(1,i) for i in range(1,4)],[bytes(8)]*3)
        self.assertEqual(t.cell(1,4),t.glyph('D'))
        t.feed(b'\x1b[7m\x1b[K')
        self.assertEqual([t.cell(1,i) for i in range(3,81)],[bytes(8)]*78)
        self.assertEqual(t.cursor,(1,3))

    def test_scroll_24_rows_and_ring_wrap(self):
        t=self.t
        for i in range(80):
            t.feed(b'\r\n' + bytes([65+i%26]))
        self.assertEqual(t.cursor,(24,2))
        for row in range(1,25):
            self.assertEqual(t.cell(row,1),t.glyph(chr(65+(55+row)%26)))
        self.assertEqual([t.cell(25,col) for col in range(1,81)],[bytes(8)]*80)

    def test_unsupported_sequences_and_cancellation(self):
        t=self.t
        t.feed(b'\x1b[5;5H\x1b(B\x1b)0\x1b#8\x1b[1 q\x1b[?2H')
        self.assertEqual(t.cursor,(5,5))
        t.feed(b'\x1b]title\x07\x1bPignored\x1b\\X')
        self.assertEqual(t.cell(5,5),t.glyph('X'))
        t.feed(b'\x1b[99\x18Y\x1b[1;\x1b[HZ')
        self.assertEqual(t.cell(5,6),t.glyph('Y'))
        self.assertEqual(t.cell(1,1),t.glyph('Z'))

    def test_parameter_overflow_does_not_corrupt_memory(self):
        t=self.t
        guard=SYMS['NUMBERBUFFER']+20
        before=bytes(t.mem[guard:guard+32])
        t.feed(b'\x1b[' + b'1;'*200 + b'HX')
        self.assertEqual(bytes(t.mem[guard+2:guard+32]),before[2:]) # pointer may change
        self.assertEqual(t.cell(1,1),t.glyph('X'))
        self.assertEqual(t.value('ANSISTATE'),0)

    def test_visible_cursor_does_not_change_command(self):
        t=self.t
        t.call('TOGGLECURSOR')
        t.mem[SYMS['CURSORON']]=255
        t.feed(b'\x1b[7;12H')
        self.assertEqual(t.cursor,(7,12))
        self.assertEqual(t.cell(1,1),bytes(8))

    def test_del_is_ignored_and_reset_recovers(self):
        t=self.t
        t.feed(b'AB\x7fC')
        self.assertEqual(t.cursor,(1,4))
        t.feed(b'\x1b[?7l\x1b[5;6H\x1bc')
        self.assertEqual(t.cursor,(1,1))
        self.assertEqual(t.value('AUTOWRAP'),1)
        self.assertEqual(t.cell(1,1),bytes(8))

    def test_parameter_limit_and_zero_blank(self):
        t=self.t
        t.feed(b'\x1b[' + b'0;'*15 + b'0mX')
        self.assertEqual(t.cell(1,1),t.glyph('X'))
        t.cpu.bc=0
        t.cpu.hl=0xC000
        t.call('SCREENBLANK')
        self.assertEqual(t.cell(1,1),t.glyph('X'))

    def test_visual_probe_pages(self):
        pages=list(runpy.run_path(str(ROOT/'tools/vt100_probe.py'))['pages']())
        expected=[[(5,10,'A'),(7,20,'B'),(24,80,'C')],
                  [(6,5,'O'),(6,6,'K'),(8,1,'O'),(8,2,'K')],
                  [(5,80,'X'),(6,1,'Y'),(8,80,'R'),(9,1,'Z'),(11,9,'T')],
                  [(1,1,'0'),(1,2,'9'),(24,1,'3'),(24,2,'2')],
                  [(6,1,'P'),(6,2,'A'),(6,3,'S'),(6,4,'S')],
                  [(5,1,'T'),(6,1,'B'),(9,1,'E'),(10,1,'N'),(11,1,'B')],
                  [(5,1,'T'),(6,1,'R'),(7,1,'A'),(10,1,'D'),(11,1,'B')],
                  [(16,1,'N')],[(1,1,'9')],[(1,1,'1')],
                  [(5,5,chr(218)),(5,6,chr(196)),(5,20,chr(218))],
                  [(1,1,'1')],[(1,1,'1')]]
        self.assertEqual(len(pages),len(expected))
        for index,(page,cells) in enumerate(zip(pages,expected)):
            t=Terminal()
            t.feed_network(page)
            for row,col,char in cells:
                self.assertEqual(t.cell(row,col),t.glyph(char))
            if index == 7:
                self.assertEqual(t.cell(7,10),bytes(v^255 for v in t.glyph('S')))
            if index == 3:
                self.assertEqual([t.cell(25,col) for col in range(1,81)],
                                 [bytes(8)]*80)

    def fill_rows(self):
        for row in range(1,25):
            self.t.feed(f'\x1b[{row};1H'.encode() + bytes([64+row])*80)

    def test_region_index_and_reverse_preserve_outside_pixels(self):
        t=self.t
        # Shift the hardware start so copied rows cross its 2K bank boundary.
        t.feed(b'\x1b[24;1H' + b'\n'*13)
        self.fill_rows()
        before=[[t.cell(r,c) for c in range(1,81)] for r in range(1,26)]
        t.feed(b'\x1b[5;20r\x1b[20;13H\x1bD')
        self.assertEqual(t.cursor,(20,13))
        for r in range(1,26):
            expected=before[r] if 5 <= r < 20 else ([bytes(8)]*80 if r==20 else before[r-1])
            self.assertEqual([t.cell(r,c) for c in range(1,81)],expected)
        t.feed(b'\x1b[5;13H\x1bM')
        self.assertEqual(t.cursor,(5,13))
        for r in range(1,26):
            expected=[bytes(8)]*80 if r==5 else before[r-1]
            self.assertEqual([t.cell(r,c) for c in range(1,81)],expected)

    def test_full_screen_reverse_index(self):
        t=self.t
        self.fill_rows()
        t.feed(b'\x1b[1;17H\x1bM')
        self.assertEqual(t.cursor,(1,17))
        self.assertEqual(t.cell(1,1),bytes(8))
        for row in range(2,25):
            self.assertEqual(t.cell(row,1),t.glyph(chr(63+row)))
        self.assertEqual([t.cell(25,c) for c in range(1,81)],[bytes(8)]*80)

    def test_margins_defaults_validation_and_home(self):
        t=self.t
        t.feed(b'\x1b[5;20r')
        self.assertEqual(t.cursor,(1,1))
        for invalid in [b'10;10',b'20;5',b'1;25',b'255;255',b'1;20;2']:
            t.feed(b'\x1b[8;9H\x1b['+invalid+b'r')
            self.assertEqual((t.value('SCROLLTOP'),t.value('SCROLLBOTTOM')),(4,19))
            self.assertEqual(t.cursor,(8,9))
        t.feed(b'\x1b[;r')
        self.assertEqual((t.value('SCROLLTOP'),t.value('SCROLLBOTTOM')),(0,23))
        t.feed(b'\x1b[5;0r')
        self.assertEqual((t.value('SCROLLTOP'),t.value('SCROLLBOTTOM')),(4,23))
        t.feed(b'\x1b[0;0r')
        self.assertEqual((t.value('SCROLLTOP'),t.value('SCROLLBOTTOM')),(0,23))

    def test_origin_relative_cursor_and_motion_limits(self):
        t=self.t
        t.feed(b'\x1b[5;20r\x1b[?6h')
        self.assertEqual(t.cursor,(5,1))
        t.feed(b'\x1b[2;10H')
        self.assertEqual(t.cursor,(6,10))
        t.feed(b'\x1b[999;999H')
        self.assertEqual(t.cursor,(20,80))
        t.feed(b'\x1b[999A')
        self.assertEqual(t.cursor,(5,80))
        t.feed(b'\x1b[999B')
        self.assertEqual(t.cursor,(20,80))
        t.feed(b'\x1b[?6l\x1b[2;10H\x1b[999A')
        self.assertEqual(t.cursor,(1,10))
        t.feed(b'\x1b[23;10H\x1b[999B')
        self.assertEqual(t.cursor,(24,10))

    def test_index_outside_region_and_nel(self):
        t=self.t
        self.fill_rows()
        t.feed(b'\x1b[5;20r\x1b[24;10H\n')
        self.assertEqual(t.cursor,(24,10))
        self.assertEqual(t.cell(5,1),t.glyph('E'))
        t.feed(b'\x1b[1;10H\x1bM')
        self.assertEqual(t.cursor,(1,10))
        t.feed(b'\x1b[4;10H\x1bE')
        self.assertEqual(t.cursor,(5,1))
        t.feed(b'\x1b[20;80HXZ')
        self.assertEqual(t.cursor,(20,2))
        self.assertEqual(t.cell(19,80),t.glyph('X'))
        self.assertEqual(t.cell(20,1),t.glyph('Z'))
        self.assertEqual(t.cell(21,1),t.glyph('U'))

    def test_dec_cursor_restores_attributes_origin_and_wrap(self):
        t=self.t
        t.feed(b'\x1b[5;20r\x1b[?6h\x1b[2;80H\x1b[7mX\x1b7')
        t.feed(b'\x1b[0m\x1b[?6;7l\x1b[1;1H\x1b8Y')
        self.assertEqual(t.cursor,(7,2))
        self.assertEqual(t.value('ORIGINMODE'),1)
        self.assertEqual(t.value('AUTOWRAP'),1)
        self.assertEqual(t.cell(7,1),bytes(v^255 for v in t.glyph('Y')))
        # Changing margins between save/restore clamps an origin-relative save.
        t.feed(b'\x1b[10;15r\x1b8')
        self.assertEqual(t.cursor,(10,80))
        self.assertEqual(t.value('WRAPPENDING'),0)

    def test_arrow_packets_and_reset(self):
        t=self.t
        t.cpu.ix=0xABCD
        t.cpu.iy=0x1234
        def packet(key):
            t.call('ENCODEKEY',key)
            p=SYMS['SENDSIZE']
            n=int.from_bytes(t.mem[p:p+2],'little')
            self.assertEqual(t.value('CMDSEND'),n+5)
            self.assertEqual((t.cpu.ix,t.cpu.iy),(0xABCD,0x1234))
            p=SYMS['SENDTEXT']
            return bytes(t.mem[p:p+n])
        for mode,prefix in [(b'\x1b[?1l',b'\x1b['),(b'\x1b[?1h',b'\x1bO')]:
            t.feed(mode)
            for key,final in zip(range(0xF0,0xF4),b'ABDC'):
                self.assertEqual(packet(key),prefix+bytes([final]))
        self.assertEqual(packet(ord('a')),b'a')
        self.assertEqual(packet(13),b'\r\n')
        self.assertEqual(packet(255),b'\xff\xff')
        t.feed(b'\x1b[5;20r\x1b[?1;6h\x1bc')
        self.assertEqual(packet(0xF0),b'\x1b[A')
        self.assertEqual((t.value('SCROLLTOP'),t.value('SCROLLBOTTOM')),(0,23))
        self.assertEqual(t.value('ORIGINMODE'),0)

    def test_probe_arrow_input_fragmentation_and_feedback(self):
        probe=runpy.run_path(str(ROOT/'tools/vt100_probe.py'))
        decoder=probe['ProbeInput']()
        events=[]
        for part in [b'\x1b', b'[', b'A\x1bO', b'D', b' r']:
            events.extend(decoder.feed(part))
        self.assertEqual(events,[b'\x1b[A',b'\x1bOD',b' ',b'r'])
        self.assertIn(b'PASS UP',probe['arrow_feedback'](events[0],False))
        self.assertIn(b'PASS LEFT',probe['arrow_feedback'](events[1],True))
        self.assertIn(b'FAIL',probe['arrow_feedback'](events[0],True))

    def test_probe_pages_repeat_and_cycle_without_mode_leaks(self):
        pages=list(runpy.run_path(str(ROOT/'tools/vt100_probe.py'))['pages']())
        for _ in range(2):
            for index,page in enumerate(pages):
                self.t.feed_network(page)
                self.t.feed_network(page)
                self.assertEqual(self.t.value('ORIGINMODE'),0)
                self.assertEqual(self.t.value('CURSORKEYMODE'),int(index==9))
                if index not in (5,6,7):
                    self.assertEqual((self.t.value('SCROLLTOP'),
                                      self.t.value('SCROLLBOTTOM')),(0,23))

    def net(self,data):
        for byte in data:
            self.t.call('TELNETBYTE',byte)

    def test_dec_graphics_g0_g1_ascii_and_saved_designations(self):
        t=self.t
        t.feed(b'\x1b(0lqk\x1b(Bq\x1b)0\x0ex\x0fq')
        for col,code in [(1,218),(2,196),(3,191),(4,ord('q')),(5,179),(6,ord('q'))]:
            self.assertEqual(t.cell(1,col),t.glyph(chr(code)))
        t.feed(b'\x0e\x1b7\x1b)B\x0f\x1b8x')
        self.assertEqual(t.cell(1,7),t.glyph(chr(179)))
        t.feed(b'\x1bcq')
        self.assertEqual(t.cell(1,1),t.glyph('q'))
        self.assertEqual((t.value('G0CHARSET'),t.value('G1CHARSET'),t.value('ACTIVECHARSET')),(0,0,0))

    def test_graphics_scanlines_and_uk(self):
        t=self.t
        t.feed(b'\x1b(0oprs\x1b(A#\x1b(B#')
        for col,row in [(1,0),(2,2),(3,5),(4,7)]:
            pixels=bytearray(8);pixels[row]=255
            self.assertEqual(t.cell(1,col),bytes(pixels))
        self.assertEqual(t.cell(1,5),t.glyph(chr(156)))
        self.assertEqual(t.cell(1,6),t.glyph('#'))

    def test_status_attributes_and_relative_cursor_reports(self):
        t=self.t
        t.feed(b'\x1b[c\x1b[0c\x1bZ\x1b[5n\x1b[24;80H\x1b[6n')
        self.assertEqual(t.packets,[b'\x1b[?1;0c']*3+[b'\x1b[0n',b'\x1b[24;80R'])
        t.feed(b'X\x1b[6nY')
        self.assertEqual(t.packets[-1],b'\x1b[24;80R')
        self.assertEqual(t.cursor,(24,2))
        t.feed(b'\x1b[5;20r\x1b[?6h\x1b[2;3H\x1b[6n')
        self.assertEqual(t.packets[-1],b'\x1b[2;3R')
        before=t.packets[:]
        t.feed(b'\x1b[?6n\x1b[99n\x1b[1c\x1b[5;6n')
        self.assertEqual(t.packets,before)

    def test_telnet_type_window_size_and_duplicate_options(self):
        t=self.t
        self.net(b'\xff\xfd\x18')
        self.assertEqual(t.packets,[b'\xff\xfb\x18'])
        self.net(b'\xff\xfa\x18\x01\xff\xf0')
        self.assertEqual(t.packets[-1],b'\xff\xfa\x18\x00VT100\xff\xf0')
        self.net(b'\xff\xfd\x1f')
        self.assertEqual(t.packets[-2:],[b'\xff\xfb\x1f',b'\xff\xfa\x1f\x00P\x00\x18\xff\xf0'])
        before=t.packets[:]
        self.net(b'\xff\xfd\x18\xff\xfd\x1f')
        self.assertEqual(t.packets,before)
        self.net(b'\xff\xfa\x18\x01\xff\xf0')
        self.assertEqual(t.packets[-1],b'\xff\xfa\x18\x00VT100\xff\xf0')

    def test_telnet_refusals_and_disable_acknowledgements(self):
        t=self.t
        # Original BSD login sequence: DONT ECHO must not disable remote ECHO.
        self.net(b'\xff\xfb\x01\xff\xfb\x03\xff\xfd\x01\xff\xfe\x01')
        self.assertEqual(t.packets,[b'\xff\xfd\x01',b'\xff\xfd\x03',b'\xff\xfc\x01'])
        self.assertEqual(t.value('REMOTEECHO'),1)
        self.net(b'\xff\xfc\x01\xff\xfc\x01')
        self.assertEqual(t.packets[-1],b'\xff\xfe\x01')
        self.assertEqual(t.value('REMOTEECHO'),0)
        self.net(b'\xff\xfd\x18\xff\xfe\x18\xff\xfe\x18')
        self.assertEqual(t.packets[-2:],[b'\xff\xfb\x18',b'\xff\xfc\x18'])
        before=t.packets[:]
        self.net(b'\xff\xfa\x18\x01\xff\xf0')
        self.assertEqual(t.packets,before)
        self.net(b'\xff\xfb\x63\xff\xfd\x63')
        self.assertEqual(t.packets[-2:],[b'\xff\xfe\x63',b'\xff\xfc\x63'])

    def test_telnet_partial_commands_escaped_iac_and_bounded_subnegotiation(self):
        t=self.t
        self.net(b'\xff')
        t.call('ENCODEKEY',ord('a')) # An incomplete IAC does not block keyboard processing
        self.assertEqual(t.value('TELNETSTATE'),1)
        self.net(b'\xfd\x18\xff\xfa\x18\x01'+b'x'*500+b'\xff\xf0')
        self.assertEqual(t.packets,[b'\xff\xfb\x18'])
        self.net(b'\xff\xfa\x18\x01\xff\xff\xff\xf0')
        self.assertEqual(t.packets,[b'\xff\xfb\x18'])
        self.net(b'\xff\xffA\xff\xf1B') # IAC IAC literal, NOP consumed
        self.assertEqual(t.cell(1,1),t.glyph(chr(255)))
        self.assertEqual(t.cell(1,2),t.glyph('A'))
        self.assertEqual(t.cell(1,3),t.glyph('B'))
        # A negotiation can occur in the middle of an ANSI sequence.
        self.net(b'\x1b[4;\xff\xfd\x03' + b'7HX')
        self.assertEqual(t.cell(4,7),t.glyph('X'))
        t.call('RESETTELNET')
        self.assertEqual((t.value('TELNETSTATE'),t.value('LOCALTT')),(0,0))

    def test_probe_reports_and_negotiation_round_trip(self):
        probe=runpy.run_path(str(ROOT/'tools/vt100_probe.py'))
        screens=list(probe['pages']())
        for index,labels in [(11,[b'PASS ready',b'PASS VT100 ID',b'PASS cursor 7;13']),
                             (12,[b'PASS VT100',b'PASS 80x24'])]:
            t=Terminal()
            # Repeat page 13 to check withdrawal/re-enable as well as first use.
            for _ in range(2):
                t.packets.clear()
                t.feed_network(screens[index])
                decoder=probe['ProbeInput']()
                feedback=b''
                for packet in t.packets:
                    for byte in packet:
                        for event in decoder.feed(bytes([byte])):
                            feedback+=probe['report_feedback'](event,index)
                for label in labels:
                    self.assertIn(label,feedback)
                self.assertNotIn(b'Unexpected',feedback)
                t.feed_network(feedback)

    def test_receive_batches_preserve_input_across_replies_and_boundaries(self):
        # Both Telnet replies and DSR overwrite the shared M4 response buffer.
        # Compare the complete screen against the existing byte-at-a-time path.
        data=(b'A'*61+b'\xff\xfd\x18'+b'\xff\xfa\x18\x01\xff\xf0'
              +b'\x1b[5;7Hhello\x1b[6nWORLD\r\n'
              +b'\xff\xff'+b'Z'*150+b'\x1b[7mEND\x1b[0m')
        reference=Terminal()
        reference.feed_network(data)
        for chunk in [1,2,7,63,64]:
            with self.subTest(chunk=chunk):
                t=Terminal()
                m=t.cpu
                m.ix=0xA100
                m.iy=0xA200
                pending=bytearray(data)
                requests=[]
                def command():
                    if m.hl==SYMS['CMDRECV']:
                        requested=int.from_bytes(t.mem[m.hl+4:m.hl+6],'little')
                        self.assertEqual(requested,64)
                        requests.append(requested)
                        count=min(requested,chunk,len(pending))
                        t.mem[m.iy+3]=0
                        t.mem[m.iy+4:m.iy+6]=count.to_bytes(2,'little')
                        t.mem[m.iy+6:m.iy+6+count]=pending[:count]
                        del pending[:count]
                        t.mem[m.ix+2:m.ix+4]=len(pending).to_bytes(2,'little')
                    elif m.hl==SYMS['CMDSEND']:
                        count=int.from_bytes(t.mem[m.hl+4:m.hl+6],'little')
                        t.packets.append(bytes(t.mem[m.hl+6:m.hl+6+count]))
                        t.mem[m.iy:m.iy+80]=b'!'*80
                    else:
                        self.fail('unexpected M4 command')
                t.hooks[SYMS['SENDCMD']]=command
                t.mem[m.ix+2:m.ix+4]=len(pending).to_bytes(2,'little')
                while pending:
                    before=len(requests)
                    t.call('RECV_NOBLOCK2')
                    self.assertEqual(len(requests),before+1)
                    self.assertEqual((m.ix,m.iy),(0xA100,0xA200))
                self.assertEqual(len(requests),(len(data)+chunk-1)//chunk)
                t.call('RECV_NOBLOCK2') # Empty socket: no M4 command.
                self.assertEqual(len(requests),(len(data)+chunk-1)//chunk)
                self.assertEqual(t.cursor,reference.cursor)
                self.assertEqual(t.packets,reference.packets)
                for row in range(1,26):
                    for col in range(1,81):
                        self.assertEqual(t.cell(row,col),reference.cell(row,col))

    def test_receive_zero_length_response_does_not_process_stale_bytes(self):
        t=self.t
        m=t.cpu
        m.ix=0xA100
        m.iy=0xA200
        t.mem[m.ix+2]=1
        def command():
            self.assertEqual(m.hl,SYMS['CMDRECV'])
            t.mem[m.iy+3:m.iy+6]=bytes(3)
            t.mem[m.iy+6:m.iy+70]=b'X'*64
        t.hooks[SYMS['SENDCMD']]=command
        t.call('RECV_NOBLOCK2')
        self.assertEqual(t.cursor,(1,1))
        self.assertEqual(t.cell(1,1),bytes(8))

    def test_connect_escape_closes_socket_and_unwinds_on_repeat(self):
        t=self.t
        m=t.cpu
        t.mem[0xFF02:0xFF04]=(0xA000).to_bytes(2,'little')
        t.mem[0xFF06:0xFF08]=(0xA100).to_bytes(2,'little')
        commands=[]
        keys=[]
        def command():
            commands.append(m.hl)
            if m.hl==SYMS['CMDSOCKET']:
                t.mem[0xA003]=2
            elif m.hl==SYMS['CMDCONNECT']:
                t.mem[0xA003]=0
                t.mem[0xA120]=1
            elif m.hl==SYMS['CMDCLOSE']:
                self.assertEqual(t.mem[m.hl+3],2)
                t.mem[0xA120]=0
            else:
                self.fail('unexpected command')
        def keyboard():
            carry,char=keys.pop(0)
            m.a=char
            m.f=(m.f&254)|carry
        t.hooks[SYMS['SENDCMD']]=command
        t.hooks[0xBB09]=keyboard
        m.set_breakpoint(0xBB09)
        for key in [27,0xFC]*10:
            keys[:]=[(0,27),(1,ord('a')),(1,key)]
            commands.clear()
            t.call('TELNET_SESSION')
            self.assertEqual(keys,[])
            self.assertEqual(commands,[SYMS[n] for n in ('CMDSOCKET','CMDCONNECT','CMDCLOSE')])
            self.assertEqual(m.sp,0xB002)

    def test_connected_disconnect_paths_return_without_stack_leaks(self):
        for reason in ['escape','remote','recv_error','send_error','paused_escape']:
            with self.subTest(reason=reason):
                t=Terminal()
                m=t.cpu
                t.mem[0xFF02:0xFF04]=(0xA200).to_bytes(2,'little')
                t.mem[0xFF06:0xFF08]=(0xA100).to_bytes(2,'little')
                commands=[]
                keys=[]
                def command():
                    commands.append(m.hl)
                    if m.hl==SYMS['CMDSOCKET']:
                        t.mem[0xA203]=2
                    elif m.hl==SYMS['CMDCONNECT']:
                        t.mem[0xA203]=0
                        t.mem[0xA120:0xA124]=bytes(4)
                    elif m.hl==SYMS['CMDRECV']:
                        t.mem[0xA203]=255
                    elif m.hl==SYMS['CMDCLOSE']:
                        self.assertEqual(t.mem[m.hl+3],2)
                    else:
                        self.fail('unexpected command')
                def keyboard():
                    m.a=keys.pop(0)
                    m.f |= 1
                    if reason=='send_error':
                        t.mem[0xA120]=3
                def connected():
                    if reason=='remote':
                        t.mem[0xA120]=3
                    elif reason=='recv_error':
                        t.mem[0xA122]=1
                t.hooks[SYMS['SENDCMD']]=command
                t.hooks[0xBB09]=keyboard
                m.set_breakpoint(0xBB09)
                # Inject socket state after WaitForConnect accepts the connection.
                t.hooks[SYMS['RESETTELNET']]=connected
                m.set_breakpoint(SYMS['RESETTELNET'])
                for _ in range(30):
                    # Firmware pointers live in ROM on CPC; restore them because
                    # this flat-memory harness also draws screen RAM there.
                    t.mem[0xFF02:0xFF04]=(0xA200).to_bytes(2,"little")
                    t.mem[0xFF06:0xFF08]=(0xA100).to_bytes(2,"little")
                    commands.clear()
                    keys[:]=([9,ord('a'),0xFC] if reason=='paused_escape' else
                             [ord('a')] if reason=='send_error' else [0xFC])
                    t.call('TELNET_SESSION')
                    self.assertEqual(commands.count(SYMS['CMDCLOSE']),1)
                    self.assertEqual(m.sp,0xB002)

    def test_row_copy_all_hardware_scroll_offsets_both_directions(self):
        t=self.t
        original=bytes((i*37+i//256)%256 for i in range(16384))
        for offset in range(0,2048,16):
            for source,dest in [(0,1),(1,0),(22,23),(23,22)]:
                t.mem[0xC000:0x10000]=original
                t.mem[SYMS['SCREENOFFSET']:SYMS['SCREENOFFSET']+2]=offset.to_bytes(2,'little')
                expected=bytearray(original)
                for raster in range(8):
                    for col in range(80):
                        src=raster*2048+(offset+source*80+col)%2048
                        dst=raster*2048+(offset+dest*80+col)%2048
                        expected[dst]=original[src]
                t.cpu.e=dest
                t.call('COPYTEXTROW',source)
                self.assertEqual(bytes(t.mem[0xC000:0x10000]),expected)

    def test_block_clear_ring_edges_and_untouched_screen_memory(self):
        t=self.t
        original=bytes((i*37+i//256)%255+1 for i in range(16384))
        starts=set(range(0,2048,16)) | {1,79,80,175,176,177,1967,1968,1969,2046,2047}
        for start in sorted(starts):
            for count in [0,1,2,3,4,79,80,160,1919,1920,2000,2048]:
                t.mem[0xC000:0x10000]=original
                expected=bytearray(original)
                for raster in range(8):
                    for col in range(count):
                        expected[raster*2048+(start+col)%2048]=0
                t.cpu.hl=0xC000+start
                t.cpu.bc=count
                t.cpu.ix=0xA100
                t.cpu.iy=0xA200
                t.call('SCREENBLANK')
                self.assertEqual(bytes(t.mem[0xC000:0x10000]),expected,(start,count))
                self.assertEqual(t.cpu.hl,0xC000+(start+count)%2048)
                self.assertEqual(t.cpu.bc,0)
                self.assertEqual((t.cpu.ix,t.cpu.iy),(0xA100,0xA200))

    def test_plain_glyph_path_matches_buffered_path(self):
        fast=Terminal()
        slow=Terminal()
        # Force the buffered path without changing glyphs: UK maps only '#'.
        slow.feed(b'\x1b(A')
        data=bytes(c for c in range(32,256) if c not in (35,127))
        for t in [fast,slow]:
            t.feed(b'\x1b[24;70H'+data)
        self.assertEqual(fast.cursor,slow.cursor)
        self.assertEqual(bytes(fast.mem[0xC000:]),bytes(slow.mem[0xC000:]))

    def test_cached_glyph_mode_matches_buffered_rendering_across_transitions(self):
        fast=Terminal()
        reference=Terminal()
        transitions=[b'\x1b[0m',b'\x1b[1m',b'\x1b[2m',b'\x1b[3m',b'\x1b[4m',
                     b'\x1b[7m',b'\x1b[8m',b'\x1b[22;24;27;28m',
                     b'\x1b[31;41m',b'\x1b[37;40m',b'\x1b[0m',
                     b'\x1b(0',b'\x1b(B',b'\x1b(A',b'\x1b)0\x0e',
                     b'\x0f',b'\x1b)B\x0e',b'\x1b[1;7m\x1b7',
                     b'\x1b[0m\x1b(B\x0f',b'\x1b8',b'\x1bc']
        for seq in transitions:
            fast.feed(seq)
            reference.feed(seq)
            attrs=all(fast.value(n)==0xC9 for n in
                      ['JITALICS','JBOLD','JUNDER','JINVERSE','JSMASH'])
            charset=fast.value('G1CHARSET' if fast.value('ACTIVECHARSET') else 'G0CHARSET')
            self.assertEqual(fast.value('BUFFEREDGLYPHREQUIRED'),int(not(attrs and charset==0)),seq)
            for char in b'Ab#_qx~'+bytes([156,196,255]):
                fast.feed(bytes([char]))
                reference.mem[SYMS['BUFFEREDGLYPHREQUIRED']]=1
                reference.feed(bytes([char]))
            self.assertEqual(fast.cursor,reference.cursor,seq)
            self.assertEqual(bytes(fast.mem[0xC000:]),bytes(reference.mem[0xC000:]),seq)
        fast.call('RESETTERMINALMODES')
        fast.call('ALLOFF')
        self.assertEqual(fast.value('BUFFEREDGLYPHREQUIRED'),0)

    def test_manual_address_delete_updates_buffer_and_display(self):
        for col in [1,78,79,80]:
            for delete in [8,127]:
                with self.subTest(col=col,delete=delete):
                    t=Terminal()
                    t.feed(f'\x1b[5;{col}H'.encode())
                    keys=list(bytes([delete])+b'12x'+bytes([delete,delete])+b'3'+bytes([delete])+b'45\r')
                    def keyboard():
                        t.cpu.a=keys.pop(0)
                        t.cpu.f |= 1
                    t.hooks[0xBB09]=keyboard
                    t.cpu.set_breakpoint(0xBB09)
                    t.cpu.hl=SYMS['BUF']
                    t.call('GET_TEXTINPUT')
                    self.assertEqual(bytes(t.mem[SYMS['BUF']:SYMS['BUF']+4]),b'145\0')
                    self.assertEqual(t.cpu.bc,3)
                    expected=Terminal()
                    expected.feed(f'\x1b[5;{col}H145'.encode())
                    self.assertEqual(t.cursor,expected.cursor)
                    self.assertEqual(bytes(t.mem[0xC000:]),bytes(expected.mem[0xC000:]))

    def test_manual_address_rejects_controls_and_bounds_length(self):
        t=self.t
        keys=list(b'\x1b\t\x01'+b'a'*140+b'\x7fb\r')
        def keyboard():
            t.cpu.a=keys.pop(0)
            t.cpu.f |= 1
        t.hooks[0xBB09]=keyboard
        t.cpu.set_breakpoint(0xBB09)
        t.cpu.hl=SYMS['BUF']
        t.mem[SYMS['BUF']+128]=0xA5
        t.call('GET_TEXTINPUT')
        self.assertEqual(t.cpu.bc,127)
        self.assertEqual(bytes(t.mem[SYMS['BUF']:SYMS['BUF']+128]),b'a'*126+b'b\0')
        self.assertEqual(t.mem[SYMS['BUF']+128],0xA5)

    def test_socket_error_is_returned_without_waiting_for_keyboard(self):
        t=self.t
        t.cpu.ix=0xA100
        for code in range(240,256):
            t.mem[0xA100]=code
            t.call('RECV_NOBLOCK2')
            self.assertEqual(t.cpu.a,code)
            self.assertTrue(t.cpu.f&1)
            self.assertEqual(t.cpu.sp,0xB002)

    def test_connect_wait_success_and_errors(self):
        t=self.t
        m=t.cpu
        m.ix=0xA100
        for status in [0,3,255]:
            t.mem[m.ix]=status
            t.call('WAITFORCONNECT')
            self.assertEqual(m.a,status)
        t.mem[m.ix]=1
        def completes():
            t.mem[m.ix]=0
            m.a=27
            m.f &= 254  # no key: stale A must not be interpreted as Escape
        t.hooks[0xBB09]=completes
        m.set_breakpoint(0xBB09)
        t.call('WAITFORCONNECT')
        self.assertEqual(m.a,0)

    def test_controls_inside_csi(self):
        self.t.feed(b'\x1b[5;\x07' + b'7H')
        self.assertEqual(self.t.cursor,(5,7))


if __name__ == '__main__':
    unittest.main()
