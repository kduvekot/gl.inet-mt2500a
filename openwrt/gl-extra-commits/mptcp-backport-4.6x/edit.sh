#!/bin/sh
# GL.iNet's MPTCP backport as their 4.6.x kernels had it: ../mptcp-backport
# (the published backport and our patches for it) plus 999-9999-5 from
# files/ here (the receive path still reports subflow priority changes;
# commented out from 4.7.0 on). The same single commit as mptcp-backport.
set -e
base="$(dirname "$0")/../mptcp-backport"
cp -r "$base/files/." .
(cd "$base/files" && find . -type f) | xargs git add
sh "$base/edit.sh"
