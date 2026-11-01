#!/bin/sh
# ARMv8 crypto extensions and NEON built in for the MT7981 (GL.iNet, 4.8.2+):
# the options of options.txt (as in GL.iNet's published MT7987 target
# config, all =y in GL.iNet's 4.8.2 kernel config, none in 4.7.4), merged
# into the sorted target config; they override generic's "is not set".
set -e
f=target/linux/mediatek/mt7981/config-5.4
o="$(dirname "$0")/options.txt"
! grep -q -F -f "$o" "$f"
LC_ALL=C sort -m "$f" "$o" > "$f.new"
mv "$f.new" "$f"
[ "$(grep -c -x -F -f "$o" "$f")" = "$(grep -c . "$o")" ]
