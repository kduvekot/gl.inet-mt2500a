#!/bin/sh
# 4.9.0 kernel config: CFG80211=m and NET_SCH_PRIO=y. With the kernel's
# defaults for the rest (signed regulatory database, its RSA/X.509/PKCS#7
# support built in, ASN1 and OID_REGISTRY built in), this gives GL.iNet's
# 4.9.0 kernel configuration exactly (olddefconfig test, 2026-10-28). No
# cfg80211 module is shipped: only the built-in parts change the kernel.
# Our construction of GL.iNet's change, in the MT7981 target config.
set -e
f=target/linux/mediatek/mt7981/config-5.4
for l in CONFIG_CFG80211=m CONFIG_NET_SCH_PRIO=y; do
  k=${l%%=*}
  if grep -q "^$k=" "$f"; then echo "$k already set" >&2; exit 1; fi
  awk -v l="$l" -v k="$k" 'BEGIN { done = 0 }
    !done { split($0, a, "="); kk = a[1]; sub(/^# /, "", kk); sub(/ is not set$/, "", kk)
            if (kk > k) { print l; done = 1 } }
    { print } END { if (!done) print l }' "$f" > "$f.new"
  mv "$f.new" "$f"
  grep -q "^$l$" "$f"
done
