#!/usr/bin/env python3
"""Génère les icônes PWA (PNG pur, sans dépendance) : dégradé + silhouette personne."""
import zlib, struct, math, os

def lerp(a, b, t): return a + (b - a) * t

def make_png(size, path):
    w = h = size
    # couleurs dégradé (haut -> bas) : bleu -> violet
    top = (0x4f, 0x7c, 0xff)
    bot = (0x9d, 0x5c, 0xff)
    cx, cy = w / 2, h * 0.42          # centre tête
    head_r = w * 0.16
    body_cx, body_cy = w / 2, h * 1.02
    body_r = w * 0.42                  # grand cercle (épaules)
    raw = bytearray()
    for y in range(h):
        raw.append(0)                 # filtre 0 (None) par scanline
        t = y / (h - 1)
        bg = tuple(int(lerp(top[i], bot[i], t)) for i in range(3))
        for x in range(w):
            # silhouette blanche : tête (cercle) OU épaules (grand cercle bas)
            in_head = (x - cx) ** 2 + (y - cy) ** 2 <= head_r ** 2
            in_body = (x - body_cx) ** 2 + (y - body_cy) ** 2 <= body_r ** 2
            if in_head or in_body:
                r, g, b = 255, 255, 255
            else:
                r, g, b = bg
            raw += bytes((r, g, b, 255))

    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        return c + struct.pack(">I", zlib.crc32(typ + data) & 0xffffffff)

    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)
    png = sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    print(f"écrit {path} ({len(png)} octets)")

out = os.path.join(os.path.dirname(__file__), "icons")
os.makedirs(out, exist_ok=True)
for s in (192, 512, 180):
    make_png(s, os.path.join(out, f"icon-{s}.png"))
