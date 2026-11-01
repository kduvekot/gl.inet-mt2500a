# GL.iNet's newer route-failover and kmwan patches (922/923, published
# 4.8.6 tree) replace the fork's 953/954; files/ brings the new ones
h=target/linux/generic/hack-5.4
git rm -q "$h/953-support-route-failover.patch" "$h/954-support-gl-kmwan.patch"
[ -f "$h/922-support-route-failover.patch" ] && [ -f "$h/923-support-gl-kmwan.patch" ]
