#!/usr/bin/env python3
"""VNC Mouse Controller — sends proper RFB PointerEvents to QEMU's VNC server."""
import socket
import struct
import time
import sys

class VNCClient:
    def __init__(self, host='127.0.0.1', port=5900):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(5)
        self.sock.connect((host, port))
        self.width = 0
        self.height = 0
        self._handshake()
    
    def _recvexactly(self, n):
        data = b''
        while len(data) < n:
            chunk = self.sock.recv(n - len(data))
            if not chunk:
                raise ConnectionError("Connection closed")
            data += chunk
        return data
    
    def _handshake(self):
        # Step 1: Receive server version
        server_ver = self._recvexactly(12)
        print(f"Server version: {server_ver.strip()}")
        
        # Step 2: Send client version
        self.sock.sendall(b'RFB 003.008\n')
        
        # Step 3: Receive security types
        num_sec = self._recvexactly(1)[0]
        sec_types = self._recvexactly(num_sec)
        print(f"Security types: {list(sec_types)}")
        
        # Step 4: Send selected security type (None = 1)
        self.sock.sendall(bytes([1]))
        
        # Step 5: Receive security result
        result = self._recvexactly(4)
        sec_result = struct.unpack('>I', result)[0]
        if sec_result != 0:
            raise ConnectionError(f"Security handshake failed: {sec_result}")
        print("Security: OK (None)")
        
        # Step 6: Send ClientInit (shared = 1)
        self.sock.sendall(bytes([1]))
        
        # Step 7: Receive ServerInit
        init_header = self._recvexactly(24)
        self.width, self.height = struct.unpack('>HH', init_header[:4])
        name_length = struct.unpack('>I', init_header[20:24])[0]
        if name_length > 0:
            name = self._recvexactly(name_length).decode('utf-8', errors='replace')
        else:
            name = ""
        print(f"Framebuffer: {self.width}x{self.height}, Name: {name}")
    
    def pointer_event(self, x, y, button_mask=0):
        """Send a PointerEvent message.
        
        Args:
            x, y: Absolute position in framebuffer coordinates
            button_mask: 0=move, 1=left, 2=middle, 4=right
        """
        msg = struct.pack('>BBHH', 5, button_mask, int(x), int(y))
        self.sock.sendall(msg)
    
    def click(self, x, y, button=1):
        """Move to position and click."""
        self.pointer_event(x, y, 0)       # Move cursor
        time.sleep(0.05)
        self.pointer_event(x, y, button)  # Press button
        time.sleep(0.05)
        self.pointer_event(x, y, 0)       # Release button
    
    def double_click(self, x, y):
        """Double-click at position."""
        self.click(x, y)
        time.sleep(0.15)
        self.click(x, y)
    
    def close(self):
        self.sock.close()


if __name__ == '__main__':
    action = sys.argv[1] if len(sys.argv) > 1 else 'test'
    
    vnc = VNCClient()
    w, h = vnc.width, vnc.height
    
    if action == 'click':
        x = int(sys.argv[2])
        y = int(sys.argv[3])
        print(f"Clicking at ({x}, {y})...")
        vnc.click(x, y)
        print("Done")
    
    elif action == 'test':
        print(f"\nTesting mouse at center ({w//2}, {h//2})...")
        vnc.click(w // 2, h // 2)
        time.sleep(1)
        print("Test click sent")
    
    vnc.close()
