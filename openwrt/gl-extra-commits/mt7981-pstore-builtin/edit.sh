# pstore built in (GL.iNet, 4.7.4+): crash logs in RAM with the console and
# user messages. The target config wins over kmod-ramoops' =m (kconfig.pl
# 'm+' never turns y into m); PSTORE_RAM selects REED_SOLOMON. Inserted in
# the sorted file at its place.
f=target/linux/mediatek/mt7981/config-5.4
! grep -q '^CONFIG_PSTORE' "$f"
printf 'CONFIG_PSTORE_CONSOLE=y\nCONFIG_PSTORE_PMSG=y\nCONFIG_PSTORE_RAM=y\n' > "$f.add"
LC_ALL=C sort -m "$f" "$f.add" > "$f.new"
rm "$f.add"; mv "$f.new" "$f"
[ "$(grep -c '^CONFIG_PSTORE_\(CONSOLE\|PMSG\|RAM\)=y$' "$f")" = 3 ]
