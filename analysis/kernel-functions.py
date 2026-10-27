#!/usr/bin/env python3
"""Compare two arm64 kernels function by function.

    kernel-functions.py <a.elf> <b.elf>

Each input is an ELF with a symbol table: a vmlinux from our own build, or
a kernel Image whose symbols vmlinux-to-elf rebuilt from the built-in
kallsyms (https://github.com/marin-m/vmlinux-to-elf, in its own Python
environment):

    vmlinux-to-elf <Image> <out.elf>

GL.iNet's Image comes from the official image's FIT (kernel-1, LZMA). Only
function names both kernels have are compared (kallsyms and a vmlinux list
slightly different symbols), and a function's size is the gap to the next
of those, read across all sections by address; functions of equal size are
compared by machine code with PC-relative address fields masked
(b/bl, adr/adrp, b.cond, cbz/tbz, literal loads, and the low 12 bits of
the add/ldr/str that pair with adrp), so code that only moved compares
equal. Prints functions only in one kernel, size changes and same-size
functions whose code differs. Read-only.
"""
import hashlib, subprocess, sys


def load(path):
    """Function symbols {name: address} (unique names only) and a reader
    for bytes by address over all loaded sections."""
    out = subprocess.run(["readelf", "-sW", path], capture_output=True, text=True).stdout
    addr, dup = {}, set()
    for l in out.splitlines():
        f = l.split()
        if len(f) >= 8 and f[3] == "FUNC" and f[6] != "UND":
            try:
                a = int(f[1], 16)
            except ValueError:
                continue
            if f[7] in addr and addr[f[7]] != a:
                dup.add(f[7])
            addr.setdefault(f[7], a)
    for n in dup:
        del addr[n]
    secs = []
    for l in subprocess.run(["readelf", "-SW", path], capture_output=True, text=True).stdout.splitlines():
        p = l.split("]")[-1].split()
        if len(p) >= 6 and p[1] == "PROGBITS" and int(p[2], 16):
            secs.append((int(p[2], 16), int(p[3], 16), int(p[4], 16)))
    data = open(path, "rb").read()

    def read(a, e):
        b = bytearray(e - a)          # gaps between sections read as zeros
        for sa, so, sz in secs:
            lo, hi = max(a, sa), min(e, sa + sz)
            if lo < hi:
                b[lo - a:hi - a] = data[so + lo - sa: so + hi - sa]
        return bytes(b)
    return addr, read


def mask(b):
    """aarch64 words with PC-relative fields masked, so moved code compares equal"""
    m = []
    for j in range(0, len(b) - 3, 4):
        w = int.from_bytes(b[j:j + 4], "little")
        if (w & 0x7c000000) == 0x14000000: w &= 0xfc000000          # b, bl
        elif (w & 0x1f000000) == 0x10000000: w &= 0x9f00001f        # adr, adrp
        elif (w & 0xff000010) == 0x54000000: w &= 0xff00001f        # b.cond
        elif (w & 0x7e000000) == 0x34000000: w &= 0xff00001f        # cbz/cbnz
        elif (w & 0x7e000000) == 0x36000000: w &= 0xfff8001f        # tbz/tbnz
        elif (w & 0x3b000000) == 0x18000000: w &= 0xff00001f        # ldr literal
        elif (w & 0xffc00000) == 0x91000000: w &= 0xffc003ff        # add imm (adrp pairs: low12)
        elif (w & 0x3b000000) == 0x39000000: w &= 0xffc003ff        # any load/store with unsigned
                                                                    # 12-bit offset (adrp pairs)
        m.append(w)
    return hashlib.sha1(str(m).encode()).hexdigest()[:12]


def measure(addr, read, names):
    """size (gap to the next shared function) and masked code per name"""
    order = sorted((addr[n], n) for n in names)
    res = {}
    for i, (a, n) in enumerate(order[:-1]):
        e = order[i + 1][0]
        res[n] = (e - a, mask(read(a, e)) if e - a <= 1 << 20 else "huge")
    return res


(addrA, readA), (addrB, readB) = load(sys.argv[1]), load(sys.argv[2])
shared = set(addrA) & set(addrB)
A, B = measure(addrA, readA, shared), measure(addrB, readB, shared)
size = [(n, A[n][0], B[n][0]) for n in A if n in B and A[n][0] != B[n][0]]
code = [n for n in A if n in B and A[n][0] == B[n][0] and A[n][1] != B[n][1]]
print(f"functions: {len(addrA)} / {len(addrB)}; only in first {len(set(addrA) - shared)}, "
      f"only in second {len(set(addrB) - shared)}; compared {len(shared)}")
print("only in first:", " ".join(sorted(set(addrA) - shared)[:40]))
print("only in second:", " ".join(sorted(set(addrB) - shared)[:40]))
print(f"size changed: {len(size)}")
for n, a, b in sorted(size, key=lambda x: -abs(x[2] - x[1]))[:40]:
    print(f"  {n} {a} -> {b}")
print(f"same size, code differs (masked): {len(code)}")
print("  " + " ".join(sorted(code)[:60]))
