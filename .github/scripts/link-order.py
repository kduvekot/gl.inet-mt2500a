#!/usr/bin/env python3
"""Read build-machine order effects from GL.iNet's official aarch64 binaries.

GNU make 4.2 doesn't sort $(wildcard), so some outputs follow the build
machine's directory order (journey, chapter 13; the order changed between
4.2.x and 4.4.x). Both orders can be read back from the official binary:

    link-order.py iproute2 <ip-full>
        names of iproute2's static-syms.h table (X_link_util) in table order:
        the order of the code that loads each name's address (ADRP+ADD), so
        names the linker merged into longer strings ("vlan_link_util" inside
        "macvlan_link_util") are found too
    link-order.py objects <binary> <source.c> ...
        the sources in link order: by the position of each source's own
        string literals in the binary (read-only data follows link order)
"""
import re, struct, sys


def segments(data):
    """(vaddr, offset, filesz, executable) of each PT_LOAD (ELF64 little-endian)."""
    phoff, = struct.unpack_from("<Q", data, 0x20)
    phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
    out = []
    for i in range(phnum):
        p_type, p_flags, p_offset, p_vaddr, _, p_filesz = struct.unpack_from("<IIQQQQ", data, phoff + i * phentsize)
        if p_type == 1:
            out.append((p_vaddr, p_offset, p_filesz, bool(p_flags & 1)))
    return out


def cstring(data, segs, addr):
    for v, o, n, _ in segs:
        if v <= addr < v + n:
            off = o + addr - v
            return data[off:data.index(b"\0", off)].decode("latin-1")
    return None


def iproute2(path):
    data = open(path, "rb").read()
    segs = segments(data)
    names, page = [], {}
    for v, o, n, x in segs:
        if not x:
            continue
        for i in range(0, n - 3, 4):
            ins, = struct.unpack_from("<I", data, o + i)
            if ins & 0x9F000000 == 0x90000000:          # ADRP Xd, page
                imm = ((ins >> 29) & 3) | (((ins >> 5) & 0x7FFFF) << 2)
                imm -= (1 << 21) if imm & (1 << 20) else 0
                page[ins & 31] = ((v + i) & ~0xFFF) + (imm << 12)
            elif ins & 0xFFC00000 == 0x91000000:        # ADD Xd, Xn, #imm (no shift)
                rn, rd = (ins >> 5) & 31, ins & 31
                if rn in page:
                    s = cstring(data, segs, page[rn] + ((ins >> 10) & 0xFFF))
                    if s and re.fullmatch(r"[a-z0-9_]+_link_util", s) and s not in names:
                        names.append(s)
                if rd != rn:
                    page.pop(rd, None)
    return names


def objects(path, sources):
    data = open(path, "rb").read()
    lits = {}
    for src in sources:
        text = open(src, errors="replace").read()
        lits[src] = {s for s in re.findall(r'"((?:[^"\\\n]|\\.){8,})"', text) if "\\" not in s and "%" not in s}
    pos = {}
    for src, mine in lits.items():
        others = set().union(*(l for s, l in lits.items() if s != src))
        found = [data.find(s.encode() + b"\0") for s in mine - others]
        found = [f for f in found if f >= 0]
        pos[src] = min(found) if found else float("inf")
    return sorted(sources, key=lambda s: pos[s])


if __name__ == "__main__":
    if sys.argv[1] == "iproute2":
        print("\n".join(iproute2(sys.argv[2])))
    elif sys.argv[1] == "objects":
        print("\n".join(objects(sys.argv[2], sys.argv[3:])))
