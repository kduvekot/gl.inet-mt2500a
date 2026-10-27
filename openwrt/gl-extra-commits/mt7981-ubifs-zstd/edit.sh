#!/bin/sh
# 4.6.2+ kernel config: UBIFS_FS_ZSTD=y (4.5.0: not set). It selects
# CRYPTO_ZSTD, ZSTD_COMPRESS/DECOMPRESS and XXHASH, which then are built in
# instead of modules, exactly 4.6.2's other zstd changes. Our construction of
# GL.iNet's change: the line next to the other UBIFS compressors in the MT7981
# target config (shared with the MT3000, whose NAND uses UBIFS).
set -e
f=target/linux/mediatek/mt7981/config-5.4
grep -q "^CONFIG_UBIFS_FS_ZLIB=y$" $f
sed -i 's/^CONFIG_UBIFS_FS_ZLIB=y$/CONFIG_UBIFS_FS_ZLIB=y\nCONFIG_UBIFS_FS_ZSTD=y/' $f
grep -q "^CONFIG_UBIFS_FS_ZSTD=y$" $f
