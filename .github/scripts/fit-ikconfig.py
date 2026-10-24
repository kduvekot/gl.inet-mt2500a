#!/usr/bin/env python3
"""Extract the embedded kernel .config (IKCONFIG) from an OpenWrt FIT kernel image.

    fit-ikconfig.py <fit-kernel-file> <out-config>

Reads the FIT (flattened device tree) structure, takes the data of the
first images/kernel* node, decompresses it (lzma or gzip) and gunzips the
config between the IKCFG_ST marker and the end of the stream. Needs
CONFIG_IKCONFIG=y in the kernel (GL.iNet's 4.2.0 has it).
"""
import sys, struct, lzma, gzip, zlib
d = open(sys.argv[1], "rb").read()
off_s, off_str = struct.unpack(">II", d[8:16]); strs = d[off_str:]
def nm(o): return strs[o:strs.index(b"\0", o)].decode()
p = off_s; path = []; props = {}
while p < len(d):
    tok = struct.unpack(">I", d[p:p+4])[0]; p += 4
    if tok == 1:
        e = d.index(b"\0", p); path.append(d[p:e].decode()); p = (e + 4) & ~3
    elif tok == 2: path.pop()
    elif tok == 3:
        ln, no = struct.unpack(">II", d[p:p+8]); p += 8; val = d[p:p+ln]; p = (p + ln + 3) & ~3
        if len(path) >= 2 and path[-2] == "images" and path[-1].startswith("kernel"):
            props[nm(no)] = val
    elif tok == 4: continue
    else: break
comp = props.get("compression", b"none").rstrip(b"\0").decode()
data = props["data"]
print("kernel compression:", comp, "size", len(data))
if comp == "lzma":
    k = lzma.decompress(data, format=lzma.FORMAT_ALONE)
elif comp == "gzip":
    k = gzip.decompress(data)
else:
    k = data
i = k.find(b"IKCFG_ST")
if i < 0:
    sys.exit("no embedded config (CONFIG_IKCONFIG not set)")
cfg = zlib.decompressobj(16 + zlib.MAX_WBITS).decompress(k[i+8:])
open(sys.argv[2], "wb").write(cfg)
print("config lines:", cfg.count(b"\n"))
