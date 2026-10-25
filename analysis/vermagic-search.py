#!/usr/bin/env python3
"""Find which kernel config lines make OpenWrt's vermagic hash differ.

    vermagic-search.py <kernel-config.set> <target-hash> [<official IKCONFIG>]

OpenWrt 21.02 (include/kernel-defaults.mk) computes the hash in the kernel
package version as
    grep '=[ym]' .config.set | LC_ALL=C sort | mkhash md5
where .config.set is the kernel configuration before `make oldconfig`,
including OpenWrt's CONFIG_KERNEL_* switches and the kernel options that
module packages ask for. Options that don't exist in the kernel never reach
the final configuration, so two builds with identical kernels can still get
different hashes.

The script checks that it reproduces our own hash, then tries single and
paired changes to find the target hash: removing each =y/=m line, adding
each '# X is not set' line as =y, and (with the official IKCONFIG) =y/=m
lines that are only in one of the two.
"""
import hashlib
import itertools
import re
import sys


def ym(lines):
    return sorted(l for l in lines if re.search(r"=[ym]$", l))


def h(lines):
    # mkhash md5 = md5 of the input, hex
    return hashlib.md5(("\n".join(sorted(lines, key=lambda s: s.encode())) + "\n").encode()).hexdigest()


def main():
    cfg = open(sys.argv[1]).read().splitlines()
    target = sys.argv[2]
    base = ym(cfg)
    print(f"{len(base)} =y/=m lines; our hash {h(base)}; target {target}")
    unset = [m.group(1) for l in cfg if (m := re.match(r"# (CONFIG_\w+) is not set", l))]
    cands = [("drop", l) for l in base] + [("add", f"{u}=y") for u in unset]
    if len(sys.argv) > 3:
        off = {l.split("=")[0]: l for l in open(sys.argv[3]).read().splitlines() if re.search(r"=[ym]$", l)}
        ours = {l.split("=")[0]: l for l in base}
        cands += [("add", v) for k, v in off.items() if k not in ours]
        cands += [("drop", ours[k]) for k in ours if k in off and off[k] != ours[k]]
    print(f"{len(cands)} single changes to try")

    def apply(changes):
        s = set(base)
        for op, l in changes:
            (s.discard if op == "drop" else s.add)(l)
        return list(s)

    for c in cands:
        if h(apply([c])) == target:
            print("FOUND single:", c)
            return
    print("no single change; trying pairs ...")
    for a, b in itertools.combinations(cands, 2):
        if h(apply([a, b])) == target:
            print("FOUND pair:", a, b)
            return
    print("no single or paired change gives the target hash")


if __name__ == "__main__":
    main()
