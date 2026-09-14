import socket, struct, zlib, hashlib

def grab(host, port, timeout=15):
    """Connect to a QEMU VNC server (security type None) and return (w, h, rgb_bytes)."""
    s = socket.create_connection((host, port), timeout); s.settimeout(timeout)
    def rd(n):
        b = b''
        while len(b) < n:
            c = s.recv(n - len(b))
            if not c: raise EOFError
            b += c
        return b
    rd(12); s.sendall(b"RFB 003.008\n")
    types = rd(rd(1)[0])
    if 1 not in types: raise RuntimeError("VNC requires auth: %r" % types)
    s.sendall(b"\x01")
    if struct.unpack(">I", rd(4))[0] != 0: raise RuntimeError("auth failed")
    s.sendall(b"\x01")
    w, h = struct.unpack(">HH", rd(4))
    rd(16); rd(struct.unpack(">I", rd(4))[0])
    # 32bpp, true colour, BGRX little-endian
    s.sendall(struct.pack(">Bxxx", 0) + struct.pack(">BBBBHHHBBBxxx", 32,24,0,1,255,255,255,16,8,0))
    s.sendall(struct.pack(">BxHI", 2, 1, 0))          # SetEncodings: raw
    s.sendall(struct.pack(">BBHHHH", 3, 0, 0, 0, w, h))
    assert rd(1)[0] == 0
    rd(1)
    fb = bytearray(w*h*4)
    for _ in range(struct.unpack(">H", rd(2))[0]):
        x, y, rw, rh, enc = struct.unpack(">HHHHi", rd(12))
        if enc != 0: raise RuntimeError("unexpected encoding %d" % enc)
        data = rd(rw*rh*4)
        for row in range(rh):
            off = ((y+row)*w + x) * 4
            fb[off:off+rw*4] = data[row*rw*4:(row+1)*rw*4]
    s.close()
    rgb = bytearray(w*h*3)
    for i in range(w*h):
        b, g, r = fb[i*4], fb[i*4+1], fb[i*4+2]
        rgb[i*3], rgb[i*3+1], rgb[i*3+2] = r, g, b
    return w, h, bytes(rgb)

def write_png(path, w, h, rgb):
    rows = b''.join(b'\x00' + rgb[y*w*3:(y+1)*w*3] for y in range(h))
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c) & 0xffffffff)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(rows), 6))
           + chunk(b"IEND", b""))
    open(path, "wb").write(png)

def digest(rgb):
    return hashlib.sha1(rgb).hexdigest()
