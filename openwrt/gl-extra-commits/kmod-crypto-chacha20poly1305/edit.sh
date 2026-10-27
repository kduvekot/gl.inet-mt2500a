# GL.iNet's package definition (published 4.8.6 tree), before crypto-cmac
# as there; block.mk lies next to this script
f=package/kernel/linux/modules/crypto.mk
b="$(dirname "$0")/block.mk"
grep -q '^define KernelPackage/crypto-cmac$' "$f"
awk -v b="$b" '/^define KernelPackage\/crypto-cmac$/ { while ((getline l < b) > 0) print l; print ""; print "" } { print }' "$f" > "$f.new"
mv "$f.new" "$f"
grep -q '^define KernelPackage/crypto-chacha20poly1305$' "$f"
