#!/usr/bin/env python3
"""QEMU Monitor Controller — reliable telnet communication for screenshots and input."""
import socket
import time
import sys
import os

class QEMUMonitor:
    def __init__(self, host='127.0.0.1', port=4444):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(3)
        self.sock.connect((host, port))
        # Read and discard telnet negotiation + initial banner
        time.sleep(0.5)
        try:
            self.sock.recv(8192)
        except socket.timeout:
            pass

    def _clean(self, data):
        """Remove telnet IAC bytes from response."""
        result = []
        i = 0
        raw = data if isinstance(data, bytes) else data.encode()
        while i < len(raw):
            if raw[i] == 0xFF and i + 2 < len(raw):
                i += 3  # Skip IAC 3-byte sequence
            else:
                result.append(raw[i])
                i += 1
        return bytes(result).decode('utf-8', errors='replace').strip()

    def send(self, cmd):
        """Send a command to QEMU monitor and return response."""
        self.sock.sendall(cmd.encode() + b'\n')
        time.sleep(0.3)
        response = b''
        try:
            while True:
                data = self.sock.recv(4096)
                if not data:
                    break
                response += data
                if b'(qemu)' in response:
                    break
        except socket.timeout:
            pass
        return self._clean(response)

    def screendump(self, path):
        """Capture screenshot to PPM file."""
        return self.send(f'screendump {path}')

    def sendkey(self, key, holdtime=100):
        """Send a key press."""
        return self.send(f'sendkey {key} {holdtime}')

    def mouse_move(self, x, y):
        """Move mouse to absolute coordinates (0-32767 for usb-tablet)."""
        return self.send(f'mouse_move {x} {y}')

    def mouse_click(self):
        """Left click (press and release)."""
        self.send('mouse_button 1')
        time.sleep(0.1)
        self.send('mouse_button 0')


    def screendump_pair(self, ppm_path, hold_s=1.2):
        """Screendump then sleep for disk flush (setup/SSV probes)."""
        r = self.screendump(ppm_path)
        time.sleep(hold_s)
        return r

    def close(self):
        self.sock.close()


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'test'
    mon = QEMUMonitor()

    if cmd == 'screendump':
        path = sys.argv[2] if len(sys.argv) > 2 else '/tmp/qemu_shot.ppm'
        r = mon.screendump(path)
        size = os.path.getsize(path) if os.path.exists(path) else 0
        print(f'Screenshot: {path} ({size} bytes)')

    elif cmd == 'sendkey':
        key = sys.argv[2]
        r = mon.sendkey(key)
        print(f'Key sent: {key}')

    elif cmd == 'click':
        x = int(sys.argv[2])
        y = int(sys.argv[3])
        r = mon.mouse_move(x, y)
        print(f'Mouse moved to ({x}, {y})')
        mon.mouse_click()
        print('Clicked')

    elif cmd == 'test':
        # Full test: screenshot before, sendkey, screenshot after, compare
        mon.screendump('/tmp/test_before.ppm')
        print(f'Before: {os.path.getsize("/tmp/test_before.ppm")} bytes')

        mon.sendkey('down')
        time.sleep(0.5)
        mon.sendkey('down')
        time.sleep(0.5)

        mon.screendump('/tmp/test_after.ppm')
        print(f'After: {os.path.getsize("/tmp/test_after.ppm")} bytes')

        import filecmp
        if not filecmp.cmp('/tmp/test_before.ppm', '/tmp/test_after.ppm', shallow=False):
            print('RESULT: INPUT WORKS! Screenshots differ!')
        else:
            print('RESULT: No change detected')

    mon.close()
