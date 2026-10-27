#!/bin/sh
# GL.iNet's hardware check (security/gl-hw-check, published in their 4.8.6
# tree; files/ brings source and patch): switched on in the MT7981 target
# config, as GL.iNet's 4.8.2 kernel has it.
set -e
f=target/linux/mediatek/mt7981/config-5.4
! grep -q "CONFIG_SECURITY_GL_HW_CHECK" "$f"
printf 'CONFIG_SECURITY_GL_HW_CHECK=y\n' > "$f.add"
LC_ALL=C sort -m "$f" "$f.add" > "$f.new"
rm "$f.add"; mv "$f.new" "$f"
grep -q "^CONFIG_SECURITY_GL_HW_CHECK=y$" "$f"
