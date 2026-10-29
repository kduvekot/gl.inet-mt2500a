#!/bin/sh
# GL.iNet's MPTCP backport as their 4.9.0 kernel has it: ../mptcp-backport
# (the published backport and our patches for it) without 999-9999-4:
# subflow_v4_init_req() has upstream's body again, no longer the stub of
# 4.6.2-4.8.2. The same single commit as mptcp-backport.
set -e
base="$(dirname "$0")/../mptcp-backport"
(cd "$base/files" && find . -type f ! -name '999-9999-4-*') | while read -r f; do
  mkdir -p "$(dirname "$f")" && cp "$base/files/$f" "$f" && git add "$f"
done
sh "$base/edit.sh"
