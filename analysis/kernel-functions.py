#!/usr/bin/env python3
"""Compare two arm64 kernels function by function.

    kernel-functions.py <a.elf> <b.elf>

Each input is an ELF with a symbol table: a vmlinux from our own build, or
a kernel Image whose symbols vmlinux-to-elf rebuilt from the built-in
kallsyms (https://github.com/marin-m/vmlinux-to-elf, in its own Python
environment):

    vmlinux-to-elf <Image> <out.elf>

GL.iNet's Image comes from the official image's FIT (kernel-1, LZMA). A
function's size is the gap to the next function symbol; functions of equal
size are compared by machine code with PC-relative address fields masked
(b/bl, adr/adrp, b.cond, cbz/tbz, literal loads, and the low 12 bits of
the add/ldr/str that pair with adrp), so code that only moved compares
equal. Prints functions only in one kernel, size changes and same-size
functions whose code differs. Read-only.
"""
import subprocess, sys, hashlib, collections
def syms(path):
    out = subprocess.run(["readelf", "-sW", path], capture_output=True, text=True).stdout
    s = {}
    for l in out.splitlines():
        f = l.split()
        if len(f) >= 8 and f[3] == "FUNC" and f[6] != "UND":
            try: s.setdefault(int(f[1], 16), f[7])
            except ValueError: pass
    secs = subprocess.run(["readelf", "-SW", path], capture_output=True, text=True).stdout
    addr = off = size = None
    for l in secs.splitlines():
        p = l.split("]")[-1].split()
        if p[:1] in ([".text"], [".kernel"]):   # vmlinux-to-elf: one .kernel section
            addr, off, size = int(p[2], 16), int(p[3], 16), int(p[4], 16)
    assert addr is not None, "no .text/.kernel section"
    data = open(path, "rb").read()
    addrs = sorted(a for a in s if addr <= a < addr + size)
    res = {}
    for i, a in enumerate(addrs):
        e = addrs[i + 1] if i + 1 < len(addrs) else addr + size
        b = data[off + a - addr: off + e - addr]
        # mask aarch64 instructions with PC-relative fields (b/bl, adrp, adr, b.cond, cbz, tbz, ldr literal)
        words = [int.from_bytes(b[j:j+4], "little") for j in range(0, len(b) - 3, 4)]
        m = []
        for w in words:
            if (w & 0x7c000000) == 0x14000000: w &= 0xfc000000          # b, bl
            elif (w & 0x1f000000) == 0x10000000: w &= 0x9f00001f        # adr, adrp
            elif (w & 0xff000010) == 0x54000000: w &= 0xff00001f        # b.cond
            elif (w & 0x7e000000) == 0x34000000: w &= 0xff00001f        # cbz/cbnz
            elif (w & 0x7e000000) == 0x36000000: w &= 0xfff8001f        # tbz/tbnz
            elif (w & 0x3b000000) == 0x18000000: w &= 0xff00001f        # ldr literal
            elif (w & 0xffc00000) == 0x91000000: w &= 0xffc003ff        # add imm (adrp pairs: low12)
            elif (w & 0x3fc00000) == 0x39400000 or (w & 0x3fc00000) == 0x39000000 or (w & 0xbfc00000) == 0xb9400000 or (w & 0xffc00000) == 0xf9400000: w &= 0xffc003ff  # ldr/str uimm (adrp pairs)
            m.append(w)
        res.setdefault(s[a], (e - a, hashlib.sha1(str(m).encode()).hexdigest()[:12]))
    return res
A, B = syms(sys.argv[1]), syms(sys.argv[2])
size = [(n, A[n][0], B[n][0]) for n in A if n in B and A[n][0] != B[n][0]]
code = [n for n in A if n in B and A[n][0] == B[n][0] and A[n][1] != B[n][1]]
print(f"functions: {len(A)} / {len(B)}; only in first {len(set(A)-set(B))}, only in second {len(set(B)-set(A))}")
print("only in first:", " ".join(sorted(set(A) - set(B))[:30]))
print("only in second:", " ".join(sorted(set(B) - set(A))[:30]))
print(f"size changed: {len(size)}")
for n, a, b in sorted(size, key=lambda x: -abs(x[2]-x[1]))[:40]: print(f"  {n} {a} -> {b}")
print(f"same size, code differs (masked): {len(code)}")
print("  " + " ".join(sorted(code)[:60]))
