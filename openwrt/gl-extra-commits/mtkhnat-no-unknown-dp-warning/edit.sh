#!/bin/sh
# Remove the rate-limited "Unknown case of dp" warning; the flow is still
# left unlearned (return 0), as in GL.iNet's 4.5.0+ mtkhnat.ko.
set -e
f=target/linux/mediatek/files-5.4/drivers/net/ethernet/mediatek/mtk_hnat/hnat_nf_hook.c
python3 - "$f" << 'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
pat = r'printk_ratelimited\(KERN_WARNING\s*"Unknown case of dp, iif=%x --> %s\\n",\s*skb_hnat_iface\(skb\), dev->name\);\s*'
assert len(re.findall(pat, s)) == 1, "warning not found exactly once"
open(p, "w").write(re.sub(pat, "", s))
PY
