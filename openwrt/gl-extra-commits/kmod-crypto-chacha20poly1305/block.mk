define KernelPackage/crypto-chacha20poly1305
  TITLE:=ChaCha20-Poly1305 AEAD support, RFC7539 (used by strongSwan IPsec VPN)
  DEPENDS:=+kmod-crypto-aead +kmod-crypto-manager
  KCONFIG:=CONFIG_CRYPTO_CHACHA20POLY1305
  FILES:=$(LINUX_DIR)/crypto/chacha20poly1305.ko
  AUTOLOAD:=$(call AutoLoad,09,chacha20poly1305)
  $(call AddDepends/crypto)
endef

$(eval $(call KernelPackage,crypto-chacha20poly1305))
