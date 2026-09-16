#!/usr/bin/env python3
"""Serve repeatable, manually checked terminal pages to M4TERM over TCP.

Pages 1-12 isolate rendering and replies; page 13 tests Telnet negotiation.
Use --bind 0.0.0.0 for a real CPC or a CPCEMU setup using your LAN address.
"""
import argparse
import socket
import time

ESC = b'\x1b'
RESET_MODES = ESC + b'(B' + ESC + b')B' + b'\x0f' + ESC + b'[?1;6l' + ESC + b'[r' + ESC + b'[?7h'


def at(row, column):
    return f'\x1b[{row};{column}H'.encode('ascii')


def page(title, body):
    return (RESET_MODES + ESC + b'[0m' + ESC + b'[2J' + ESC + b'[H' +
            title.encode('ascii') + body + at(22, 1) +
            b'SPACE: next page   R: repeat   Q: quit')


def pages():
    yield page('1. Cursor movement and bounds',
        at(3, 1) + b'Expect A at (5,10), B at (7,20), C at (24,80).' +
        at(5, 10) + b'A' + at(9, 22) + ESC + b'[2A' + ESC + b'[2D' + b'B' +
        ESC + b'[999;999H' + b'C')
    yield page('2. Erasure preserves the cursor',
        at(3, 1) + b'Rows 6 and 8: only OK remains. No other X marks.' +
        at(6, 1) + b'XXXXXXXXXX' + at(6, 5) + ESC + b'[1K' + ESC + b'[K' + b'OK' +
        at(8, 1) + b'XXXXXXXXXX' + at(8, 1) + ESC + b'[2K' + b'OK')
    yield page('3. Delayed wrapping, CR/LF and tab',
        at(3, 1) + b'X: row 5 col 80. Y: row 6 col 1.' +
        at(4, 1) + b'R: row 8 col 80. Z: row 9 col 1. T: row 11 col 9.' +
        at(5, 80) + b'X' + ESC + b'[0mY' +
        at(8, 80) + b'R\r\nZ' + at(11, 1) + b'\tT')
    # Numbered lines should end with 09 at row 1 and 32 at row 24.
    yield (RESET_MODES + ESC + b'[0m' + ESC + b'[?7h' + ESC + b'[2J' + ESC + b'[H' +
           b'\r\n'.join(f'{n:02d} - scrolling test'.encode() for n in range(1,33)) +
           at(1, 28) + b'<- screen row 1 (line 09)' +
           at(17, 28) + b'<- screen row 17 (line 25)' +
           at(24, 28) + b'<- screen row 24; blank row below this' +
           at(22, 28) + b'4. Left numbers are LINE numbers.' +
           at(23, 28) + b'SPACE next / R repeat / Q quit')
    yield page('5. Unsupported and malformed sequences',
        at(3, 1) + b'Row 6 should read PASS with no extra characters.' +
        at(6, 1) + ESC + b'(B' + ESC + b')0' + ESC + b'[?2J' +
        ESC + b'[1 q' + ESC + b']hidden title\x07' +
        ESC + b'[' + b'1;'*100 + b'H' + b'PASS' +
        at(9, 1) + b'SPACE continues to the scrolling-region tests.')

    region = (at(5, 1) + b'TOP - must stay on row 5' +
              at(11, 1) + b'BOTTOM - must stay on row 11' +
              b''.join(at(row, 1) + bytes([65+row-6]) for row in range(6,11)) +
              ESC + b'[6;10r')
    yield page('6. Scroll a region upward',
        at(3, 1) + b'Rows 6..10 should read B C D E N (one per row).' +
        region + at(10, 1) + ESC + b'DN')
    yield page('7. Reverse-scroll a region',
        at(3, 1) + b'Rows 6..10 should read R A B C D (one per row).' +
        region + at(6, 1) + ESC + b'MR')
    yield page('8. Origin mode and DEC cursor save/restore',
        at(3, 1) + b'Inverse S at row 7 col 10. NORMAL at row 16 col 1.' +
        ESC + b'[6;10r' + ESC + b'[?6h' + at(2,10) + ESC + b'[7m' + ESC + b'7' +
        ESC + b'[0m' + ESC + b'[?6l' + at(16,1) + b'NORMAL' +
        ESC + b'8S' + ESC + b'[0m' + ESC + b'[?6l')
    yield page('9. Normal arrow-key mode',
        at(3,1) + b'Press UP, DOWN, LEFT, RIGHT. Each should report PASS.' +
        at(5,1) + b'Expected: ESC [ A / B / D / C')
    yield page('10. Application arrow-key mode',
        at(3,1) + b'Press UP, DOWN, LEFT, RIGHT. Each should report PASS.' +
        at(5,1) + b'Expected: ESC O A / B / D / C' + ESC + b'[?1h')

    yield page('11. DEC line drawing (G0 and G1)',
        at(3,1) + b'Two identical closed boxes; no l/q/k/x/m/j letters inside.' +
        at(5,5) + ESC + b'(0lqqqqk' + at(6,5) + b'x    x' +
        at(7,5) + b'mqqqqj' + ESC + b'(B' +
        at(5,20) + ESC + b')0' + b'\x0elqqqqk' + at(6,20) + b'x    x' +
        at(7,20) + b'mqqqqj' + b'\x0f' +
        at(10,1) + b'ASCII restored: lqkx' +
        at(12,1) + b'Saved graphics restored: ' + b'\x0e' + ESC + b'7' +
        ESC + b')B' + b'\x0f' + ESC + b'8qqq' + b'\x0f' + ESC + b')B')
    yield page('12. Terminal status replies',
        at(3,1) + b'Expect three PASS results below (ready, ID, cursor).' +
        ESC + b'[5n' + ESC + b'[c' + at(7,13) + ESC + b'[6n')
    yield page('13. Telnet terminal type and window size',
        at(3,1) + b'Expect PASS VT100 and PASS 80x24 below.' +
        b'\xff\xfe\x18\xff\xfe\x1f' +
        b'\xff\xfd\x18\xff\xfa\x18\x01\xff\xf0' +
        b'\xff\xfd\x1f')


class ProbeInput:
    """Decode fragmented arrow/CSI responses and Telnet commands from the client."""
    def __init__(self):
        self.pending = bytearray()

    def feed(self, data):
        for key in data:
            if not self.pending:
                if key in (27,255):
                    self.pending.append(key)
                else:
                    yield bytes([key])
                continue
            self.pending.append(key)
            p=self.pending
            done=False
            if p[0] == 27:
                if len(p) == 2:
                    done=p[1] not in b'[O'
                elif p[1] == ord('['):
                    done=0x40 <= key <= 0x7e
                else:
                    done=True
            elif len(p) == 2:
                done=p[1] not in (250,251,252,253,254)
            elif p[1] != 250:
                done=True
            elif key == 240 and p[-2] == 255:
                # An odd run of IAC bytes introduces SE; even runs are literals.
                run=0
                for value in reversed(p[:-1]):
                    if value != 255:
                        break
                    run+=1
                done=bool(run%2)
            if done or len(p) >= 256:
                yield bytes(p)
                p.clear()


def arrow_feedback(event, application):
    prefix = ESC + (b'O' if application else b'[')
    names = {b'A': 'UP', b'B': 'DOWN', b'C': 'RIGHT', b'D': 'LEFT'}
    name = names.get(event[2:], '') if event.startswith(prefix) else ''
    result = f'PASS {name}' if name else 'FAIL (unexpected key or sequence)'
    return (at(10,1) + ESC + b'[2K' + result.encode() +
            at(12,1) + ESC + b'[2K' + b'Received hex: ' + event.hex(' ').encode())


def report_feedback(event, index):
    if index == 11:
        expected={b'\x1b[0n': (10,'ready'), b'\x1b[?1;0c': (12,'VT100 ID'),
                  b'\x1b[7;13R': (14,'cursor 7;13')}
    else:
        expected={b'\xff\xfa\x18\x00VT100\xff\xf0': (10,'VT100'),
                  b'\xff\xfa\x1f\x00P\x00\x18\xff\xf0': (12,'80x24')}
        if len(event)==3 and event[:2] in (b'\xff\xfb',b'\xff\xfc'):
            return b''
    if event in expected:
        row,label=expected[event]
        return at(row,1)+ESC+b'[2K'+('PASS '+label).encode()
    return at(17,1)+ESC+b'[2KUnexpected reply: '+event.hex(' ').encode()[:55]


def send_page(conn, data, fragment):
    if not fragment:
        conn.sendall(data)
        return
    for start in range(0, len(data), fragment):
        conn.sendall(data[start:start+fragment])
        time.sleep(0.002)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bind', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=2324)
    parser.add_argument('--fragment', type=int, default=0,
                        help='send chunks of N bytes with a delay (1 stresses split sequences)')
    args = parser.parse_args()
    if args.fragment < 0:
        parser.error('--fragment must be nonnegative')
    screens = list(pages())
    with socket.socket() as server:
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((args.bind, args.port))
        server.listen(1)
        print(f'Connect M4TERM to {args.bind}:{args.port}. Ctrl-C stops the server.', flush=True)
        while True:
            conn, peer = server.accept()
            print(f'Connected: {peer}', flush=True)
            with conn:
                index = 0
                decoder = ProbeInput()
                try:
                    send_page(conn, screens[index], args.fragment)
                    while data := conn.recv(1024):
                        for event in decoder.feed(data):
                            key = event.lower()
                            if key == b'q':
                                conn.sendall(RESET_MODES)
                                break
                            if key == b' ':
                                index = (index + 1) % len(screens)
                            elif key != b'r':
                                if index in (8,9):
                                    send_page(conn, arrow_feedback(event, index == 9), args.fragment)
                                elif index in (11,12):
                                    send_page(conn, report_feedback(event,index), args.fragment)
                                continue
                            send_page(conn, screens[index], args.fragment)
                        else:
                            continue
                        break
                except (BrokenPipeError, ConnectionResetError):
                    pass


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        pass
