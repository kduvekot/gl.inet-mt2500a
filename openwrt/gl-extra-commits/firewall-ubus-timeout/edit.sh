# GL.iNet bumped the release with the timeout change (1.1 -> 1.2, 4.6.4+)
sed -i "s/^PKG_RELEASE:=1.1$/PKG_RELEASE:=1.2/" package/network/config/firewall/Makefile
grep -q "^PKG_RELEASE:=1.2$" package/network/config/firewall/Makefile
