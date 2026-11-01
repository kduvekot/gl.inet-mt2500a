#!/bin/sh
# build-date.sh <program>: the epoch (UTC) of the __DATE__ and __TIME__
# strings compiled into a program ("Sep 12 2025" and "07:33:37").
d=$(grep -a -o -E '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [ 0-9][0-9] 20[0-9][0-9]' "$1" | head -n 1)
t=$(grep -a -o -E '[0-2][0-9]:[0-5][0-9]:[0-5][0-9]' "$1" | head -n 1)
if [ -z "$d" ] || [ -z "$t" ]; then echo "build-date.sh: no date in $1" >&2; exit 1; fi
TZ=UTC date -d "$d $t" +%s
