# conninfra.ko of 4.9.0 from MediaTek's public conninfra driver (bbf588, GPL
# kernel module) as published in padavanonly/immortalwrt-mt798x (21.02 tree):
# built unmodified against our kernel with the options below, it's
# byte-identical to GL.iNet's (2026-10-28). Every file is downloaded at a
# fixed commit and checked by hash.
CONNINFRA_SRC:=https://raw.githubusercontent.com/padavanonly/immortalwrt-mt798x/015af9e3f2ca773392112946abb8c46aa2bbfaa2/package/mtk/drivers/conninfra/src

define Download/conninfra-0
  URL:=$(CONNINFRA_SRC)
  URL_FILE:=Makefile
  FILE:=conninfra-015af9e-Makefile
  HASH:=76a77bb6139ae2a6b6e273e84540b540fbd1dbabb5bea2660795ef69b411c43d
endef
$(eval $(call Download,conninfra-0))

define Download/conninfra-1
  URL:=$(CONNINFRA_SRC)
  URL_FILE:=NOTICE
  FILE:=conninfra-015af9e-NOTICE
  HASH:=78477052f8a14d5060b7159aa66e5bc9ed8fa2748c35afae5269aba2b36957fa
endef
$(eval $(call Download,conninfra-1))

define Download/conninfra-2
  URL:=$(CONNINFRA_SRC)/base/include
  URL_FILE:=msg_thread.h
  FILE:=conninfra-015af9e-base_include_msg_thread.h
  HASH:=24f46ac84b5952e568df2e71d6050be9f6fa1a928165504f862e4673f8487cef
endef
$(eval $(call Download,conninfra-2))

define Download/conninfra-3
  URL:=$(CONNINFRA_SRC)/base/include
  URL_FILE:=osal.h
  FILE:=conninfra-015af9e-base_include_osal.h
  HASH:=3f492927fbba3f3183c401a73919e34bb645016c1fdb5f39bcfc2c4bc3565c6d
endef
$(eval $(call Download,conninfra-3))

define Download/conninfra-4
  URL:=$(CONNINFRA_SRC)/base/include
  URL_FILE:=ring.h
  FILE:=conninfra-015af9e-base_include_ring.h
  HASH:=19b3c072ebe7294cef081da24868076c22b7be41441ac46c35b0703615fcb06b
endef
$(eval $(call Download,conninfra-4))

define Download/conninfra-5
  URL:=$(CONNINFRA_SRC)/base
  URL_FILE:=msg_thread.c
  FILE:=conninfra-015af9e-base_msg_thread.c
  HASH:=91dc5f05147765d00a3dffa5912caee0e055076c084134526464daa2ac937b7e
endef
$(eval $(call Download,conninfra-5))

define Download/conninfra-6
  URL:=$(CONNINFRA_SRC)/base
  URL_FILE:=osal.c
  FILE:=conninfra-015af9e-base_osal.c
  HASH:=3eafd938a0b6a51b175b53479bfdb9bf68bd943f2fcf6c5cfa3a966da03c20ce
endef
$(eval $(call Download,conninfra-6))

define Download/conninfra-7
  URL:=$(CONNINFRA_SRC)/base
  URL_FILE:=ring.c
  FILE:=conninfra-015af9e-base_ring.c
  HASH:=41c3f2e4f91ab67ec093c06562490389c7e181e37e6f3fa3f9b090ca876ffce9
endef
$(eval $(call Download,conninfra-7))

define Download/conninfra-8
  URL:=$(CONNINFRA_SRC)/core
  URL_FILE:=conninfra_core.c
  FILE:=conninfra-015af9e-core_conninfra_core.c
  HASH:=e6ab23bbaa5e050984ad568a0b337de62f1abb4746c7cc83c8e5e9c03de187e8
endef
$(eval $(call Download,conninfra-8))

define Download/conninfra-9
  URL:=$(CONNINFRA_SRC)/core/include
  URL_FILE:=conninfra_core.h
  FILE:=conninfra-015af9e-core_include_conninfra_core.h
  HASH:=577e3ce30b27be0cf88de2b8acdd5520be13006a2bd8ddfbddf1f9ed607134e1
endef
$(eval $(call Download,conninfra-9))

define Download/conninfra-10
  URL:=$(CONNINFRA_SRC)/include
  URL_FILE:=conninfra.h
  FILE:=conninfra-015af9e-include_conninfra.h
  HASH:=742359c35b204d26e282a2bb039dad973491865f079e3de4557858ed0bf8d820
endef
$(eval $(call Download,conninfra-10))

define Download/conninfra-11
  URL:=$(CONNINFRA_SRC)/platform
  URL_FILE:=consys_hw.c
  FILE:=conninfra-015af9e-platform_consys_hw.c
  HASH:=14bc2161c15feb6f727d0e2df6257b59db291262c2cfedde198945d83f2de6b9
endef
$(eval $(call Download,conninfra-11))

define Download/conninfra-12
  URL:=$(CONNINFRA_SRC)/platform
  URL_FILE:=consys_hw_plat_data.c
  FILE:=conninfra-015af9e-platform_consys_hw_plat_data.c
  HASH:=8b4e89053b065fe66968ce6941f0d77629d6bea3ea51bf9bfb83286cd80af406
endef
$(eval $(call Download,conninfra-12))

define Download/conninfra-13
  URL:=$(CONNINFRA_SRC)/platform
  URL_FILE:=consys_reg_mng.c
  FILE:=conninfra-015af9e-platform_consys_reg_mng.c
  HASH:=98f0d154df09265378749fb354e38bde8c8693a4364c25f82a50d76e9ccaa651
endef
$(eval $(call Download,conninfra-13))

define Download/conninfra-14
  URL:=$(CONNINFRA_SRC)/platform
  URL_FILE:=emi_mng.c
  FILE:=conninfra-015af9e-platform_emi_mng.c
  HASH:=8489fd99262a487d8111ca332e66e5b5a838595a9ab16922d33e977bdedbefeb
endef
$(eval $(call Download,conninfra-14))

define Download/conninfra-15
  URL:=$(CONNINFRA_SRC)/platform/include
  URL_FILE:=consys_hw.h
  FILE:=conninfra-015af9e-platform_include_consys_hw.h
  HASH:=67f11b37f1991ebdbf838d5f0f58924288c1b2e66ad1f625975c85c25242b148
endef
$(eval $(call Download,conninfra-15))

define Download/conninfra-16
  URL:=$(CONNINFRA_SRC)/platform/include
  URL_FILE:=consys_reg_base.h
  FILE:=conninfra-015af9e-platform_include_consys_reg_base.h
  HASH:=8873d565dfb329ee11a29fd84ba2d5a1156d6d204a26ddd83ca4b8b560b4986c
endef
$(eval $(call Download,conninfra-16))

define Download/conninfra-17
  URL:=$(CONNINFRA_SRC)/platform/include
  URL_FILE:=consys_reg_mng.h
  FILE:=conninfra-015af9e-platform_include_consys_reg_mng.h
  HASH:=96788efc7d11f9b3e56c96dca4c1f87a63148ad043ad1e5054a1cd870caf2332
endef
$(eval $(call Download,conninfra-17))

define Download/conninfra-18
  URL:=$(CONNINFRA_SRC)/platform/include
  URL_FILE:=consys_reg_util.h
  FILE:=conninfra-015af9e-platform_include_consys_reg_util.h
  HASH:=593678b59448f2b7f7c3b8ed9a008aa822bcac7d22ddf8aba5ccf7a350917e90
endef
$(eval $(call Download,conninfra-18))

define Download/conninfra-19
  URL:=$(CONNINFRA_SRC)/platform/include
  URL_FILE:=emi_mng.h
  FILE:=conninfra-015af9e-platform_include_emi_mng.h
  HASH:=570956efb78fa8715558bcdac4cae1074c01809b3bb7ec80d966f59b0859c463
endef
$(eval $(call Download,conninfra-19))

define Download/conninfra-20
  URL:=$(CONNINFRA_SRC)/platform/include
  URL_FILE:=plat_def.h
  FILE:=conninfra-015af9e-platform_include_plat_def.h
  HASH:=c584fa241f71cc24b4fdc8683ee012f88170938ece869eb80ee9a2ba344693da
endef
$(eval $(call Download,conninfra-20))

define Download/conninfra-21
  URL:=$(CONNINFRA_SRC)/platform/include
  URL_FILE:=pmic_mng.h
  FILE:=conninfra-015af9e-platform_include_pmic_mng.h
  HASH:=fcb2bfea13d2e304dd89f9af47010b756f99b6ce0ed0f2e289f3a71504e84d19
endef
$(eval $(call Download,conninfra-21))

define Download/conninfra-22
  URL:=$(CONNINFRA_SRC)/platform/mt7981/include
  URL_FILE:=mt7981.h
  FILE:=conninfra-015af9e-platform_mt7981_include_mt7981.h
  HASH:=ddd55799e26e1fb6a962c3e06b8c02721ab3ad0e6e101b9b5f90a2d64864935a
endef
$(eval $(call Download,conninfra-22))

define Download/conninfra-23
  URL:=$(CONNINFRA_SRC)/platform/mt7981/include
  URL_FILE:=mt7981_consys_reg.h
  FILE:=conninfra-015af9e-platform_mt7981_include_mt7981_consys_reg.h
  HASH:=373c7f29418ffbe56e8d9c96db0f417299575478e8c8629e542d55aea3c9469a
endef
$(eval $(call Download,conninfra-23))

define Download/conninfra-24
  URL:=$(CONNINFRA_SRC)/platform/mt7981/include
  URL_FILE:=mt7981_consys_reg_offset.h
  FILE:=conninfra-015af9e-platform_mt7981_include_mt7981_consys_reg_offset.h
  HASH:=841d51dbd1e5512f9586d210a57c554edff0e01d3957faf8c5ca3875fd8700fc
endef
$(eval $(call Download,conninfra-24))

define Download/conninfra-25
  URL:=$(CONNINFRA_SRC)/platform/mt7981/include
  URL_FILE:=mt7981_emi.h
  FILE:=conninfra-015af9e-platform_mt7981_include_mt7981_emi.h
  HASH:=a977abed55083f864393ed7ce0b4f58c74b5e499515653046701a34e85276a94
endef
$(eval $(call Download,conninfra-25))

define Download/conninfra-26
  URL:=$(CONNINFRA_SRC)/platform/mt7981/include
  URL_FILE:=mt7981_pmic.h
  FILE:=conninfra-015af9e-platform_mt7981_include_mt7981_pmic.h
  HASH:=a4c13e5a23bb005f4125cbc91a56ba2d4d3d2d0bbdedaf9ab4c43de9100d7f0d
endef
$(eval $(call Download,conninfra-26))

define Download/conninfra-27
  URL:=$(CONNINFRA_SRC)/platform/mt7981/include
  URL_FILE:=mt7981_pos.h
  FILE:=conninfra-015af9e-platform_mt7981_include_mt7981_pos.h
  HASH:=4bff5d46f2fcdb32b97ef497e209c4c0c00e52a0f6fa5db81049706f342922f3
endef
$(eval $(call Download,conninfra-27))

define Download/conninfra-28
  URL:=$(CONNINFRA_SRC)/platform/mt7981
  URL_FILE:=mt7981.c
  FILE:=conninfra-015af9e-platform_mt7981_mt7981.c
  HASH:=53e4ad12d4ada682cfbf89710ebff2261827ffd8b6fe7fd625ed5a9978bbb39c
endef
$(eval $(call Download,conninfra-28))

define Download/conninfra-29
  URL:=$(CONNINFRA_SRC)/platform/mt7981
  URL_FILE:=mt7981_consys_reg.c
  FILE:=conninfra-015af9e-platform_mt7981_mt7981_consys_reg.c
  HASH:=69df2aaa1a6f4e82e5d4cf3a4880bdc105982586ad9f50ea85922b932bead387
endef
$(eval $(call Download,conninfra-29))

define Download/conninfra-30
  URL:=$(CONNINFRA_SRC)/platform/mt7981
  URL_FILE:=mt7981_emi.c
  FILE:=conninfra-015af9e-platform_mt7981_mt7981_emi.c
  HASH:=730e599a4b54be050e84de1ad512143175e0bddf208bf51043e027b7787f2741
endef
$(eval $(call Download,conninfra-30))

define Download/conninfra-31
  URL:=$(CONNINFRA_SRC)/platform/mt7981
  URL_FILE:=mt7981_pmic.c
  FILE:=conninfra-015af9e-platform_mt7981_mt7981_pmic.c
  HASH:=a4e20f675f310067be9ecedf9a20ef096d20b2f98816f7cea5535b661883b910
endef
$(eval $(call Download,conninfra-31))

define Download/conninfra-32
  URL:=$(CONNINFRA_SRC)/platform/mt7981
  URL_FILE:=mt7981_pos.c
  FILE:=conninfra-015af9e-platform_mt7981_mt7981_pos.c
  HASH:=b1a851eb54cca32aac82cc7514e580e050874b7356017f35736e7f11e7a8dafe
endef
$(eval $(call Download,conninfra-32))

define Download/conninfra-33
  URL:=$(CONNINFRA_SRC)/platform/mt7986/include
  URL_FILE:=mt7986.h
  FILE:=conninfra-015af9e-platform_mt7986_include_mt7986.h
  HASH:=df8d775a3a20fffb07999605f7b468a22ae1b4d4d9b4fdf026d91f3cd80f6bb6
endef
$(eval $(call Download,conninfra-33))

define Download/conninfra-34
  URL:=$(CONNINFRA_SRC)/platform/mt7986/include
  URL_FILE:=mt7986_consys_reg.h
  FILE:=conninfra-015af9e-platform_mt7986_include_mt7986_consys_reg.h
  HASH:=e5f076e28f90dd30682066993c7c711bafec12f62bf5726f27aaf7ee254e4aff
endef
$(eval $(call Download,conninfra-34))

define Download/conninfra-35
  URL:=$(CONNINFRA_SRC)/platform/mt7986/include
  URL_FILE:=mt7986_consys_reg_offset.h
  FILE:=conninfra-015af9e-platform_mt7986_include_mt7986_consys_reg_offset.h
  HASH:=abc9836140b9891d4b20dde5c026b86f51012b089452a2353bbebdddab8b4a74
endef
$(eval $(call Download,conninfra-35))

define Download/conninfra-36
  URL:=$(CONNINFRA_SRC)/platform/mt7986/include
  URL_FILE:=mt7986_emi.h
  FILE:=conninfra-015af9e-platform_mt7986_include_mt7986_emi.h
  HASH:=b36f19a06f80aca6b84568407b1be9a787912b0115b50d6287c57f283a9579e8
endef
$(eval $(call Download,conninfra-36))

define Download/conninfra-37
  URL:=$(CONNINFRA_SRC)/platform/mt7986/include
  URL_FILE:=mt7986_pmic.h
  FILE:=conninfra-015af9e-platform_mt7986_include_mt7986_pmic.h
  HASH:=c1764a60a2ce5256d62a07f5c28674419bb90bd62d172631cf96711520b8e773
endef
$(eval $(call Download,conninfra-37))

define Download/conninfra-38
  URL:=$(CONNINFRA_SRC)/platform/mt7986/include
  URL_FILE:=mt7986_pos.h
  FILE:=conninfra-015af9e-platform_mt7986_include_mt7986_pos.h
  HASH:=734e2d847ea4427a551f57f3250b496b98088de22ab4ca1ebdf3f1673900cf5c
endef
$(eval $(call Download,conninfra-38))

define Download/conninfra-39
  URL:=$(CONNINFRA_SRC)/platform/mt7986
  URL_FILE:=mt7986.c
  FILE:=conninfra-015af9e-platform_mt7986_mt7986.c
  HASH:=94f516d9e74c04204f48b59c2f674599f918d41e8c813f6b9e0a8e1f6949f3a1
endef
$(eval $(call Download,conninfra-39))

define Download/conninfra-40
  URL:=$(CONNINFRA_SRC)/platform/mt7986
  URL_FILE:=mt7986_consys_reg.c
  FILE:=conninfra-015af9e-platform_mt7986_mt7986_consys_reg.c
  HASH:=56e8d00a492f72277da98a4d9f9eadcb8278c2f44fb6f7348cc83eec1b4f776a
endef
$(eval $(call Download,conninfra-40))

define Download/conninfra-41
  URL:=$(CONNINFRA_SRC)/platform/mt7986
  URL_FILE:=mt7986_emi.c
  FILE:=conninfra-015af9e-platform_mt7986_mt7986_emi.c
  HASH:=2f5b65725a1400c61ded2f4af7c49b5eafd285e82a033b4bf325c4d2749d985b
endef
$(eval $(call Download,conninfra-41))

define Download/conninfra-42
  URL:=$(CONNINFRA_SRC)/platform/mt7986
  URL_FILE:=mt7986_pmic.c
  FILE:=conninfra-015af9e-platform_mt7986_mt7986_pmic.c
  HASH:=1bd2b49f86b6c39a30580ded7ec50d2099db38210d82e177b2be7e1f4d46097a
endef
$(eval $(call Download,conninfra-42))

define Download/conninfra-43
  URL:=$(CONNINFRA_SRC)/platform/mt7986
  URL_FILE:=mt7986_pos.c
  FILE:=conninfra-015af9e-platform_mt7986_mt7986_pos.c
  HASH:=019d798ca684f155c2df30e91092b33f16f2d092a5f68098a4c90a9b07c8a936
endef
$(eval $(call Download,conninfra-43))

define Download/conninfra-44
  URL:=$(CONNINFRA_SRC)/platform
  URL_FILE:=pmic_mng.c
  FILE:=conninfra-015af9e-platform_pmic_mng.c
  HASH:=69ed445829da06b9c001ad6a4c57437bb9a562de39b081da063c5220bff16d73
endef
$(eval $(call Download,conninfra-44))

define Download/conninfra-45
  URL:=$(CONNINFRA_SRC)/src
  URL_FILE:=conninfra.c
  FILE:=conninfra-015af9e-src_conninfra.c
  HASH:=f61045cc567517abc4ff88327ea55d7d77e86822a05e8d3366084770d7e8e31d
endef
$(eval $(call Download,conninfra-45))

define Download/conninfra-46
  URL:=$(CONNINFRA_SRC)/src
  URL_FILE:=conninfra_dev.c
  FILE:=conninfra-015af9e-src_conninfra_dev.c
  HASH:=4e7a78e8fc6770338390f37b4ae91328eba3803db221f616af4a8c2dc7c7778c
endef
$(eval $(call Download,conninfra-46))

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) $(DL_DIR)/conninfra-015af9e-Makefile $(PKG_BUILD_DIR)/Makefile
	$(CP) $(DL_DIR)/conninfra-015af9e-NOTICE $(PKG_BUILD_DIR)/NOTICE
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/base/include
	$(CP) $(DL_DIR)/conninfra-015af9e-base_include_msg_thread.h $(PKG_BUILD_DIR)/base/include/msg_thread.h
	$(CP) $(DL_DIR)/conninfra-015af9e-base_include_osal.h $(PKG_BUILD_DIR)/base/include/osal.h
	$(CP) $(DL_DIR)/conninfra-015af9e-base_include_ring.h $(PKG_BUILD_DIR)/base/include/ring.h
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/base
	$(CP) $(DL_DIR)/conninfra-015af9e-base_msg_thread.c $(PKG_BUILD_DIR)/base/msg_thread.c
	$(CP) $(DL_DIR)/conninfra-015af9e-base_osal.c $(PKG_BUILD_DIR)/base/osal.c
	$(CP) $(DL_DIR)/conninfra-015af9e-base_ring.c $(PKG_BUILD_DIR)/base/ring.c
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/core
	$(CP) $(DL_DIR)/conninfra-015af9e-core_conninfra_core.c $(PKG_BUILD_DIR)/core/conninfra_core.c
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/core/include
	$(CP) $(DL_DIR)/conninfra-015af9e-core_include_conninfra_core.h $(PKG_BUILD_DIR)/core/include/conninfra_core.h
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/include
	$(CP) $(DL_DIR)/conninfra-015af9e-include_conninfra.h $(PKG_BUILD_DIR)/include/conninfra.h
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/platform
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_consys_hw.c $(PKG_BUILD_DIR)/platform/consys_hw.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_consys_hw_plat_data.c $(PKG_BUILD_DIR)/platform/consys_hw_plat_data.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_consys_reg_mng.c $(PKG_BUILD_DIR)/platform/consys_reg_mng.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_emi_mng.c $(PKG_BUILD_DIR)/platform/emi_mng.c
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/platform/include
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_include_consys_hw.h $(PKG_BUILD_DIR)/platform/include/consys_hw.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_include_consys_reg_base.h $(PKG_BUILD_DIR)/platform/include/consys_reg_base.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_include_consys_reg_mng.h $(PKG_BUILD_DIR)/platform/include/consys_reg_mng.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_include_consys_reg_util.h $(PKG_BUILD_DIR)/platform/include/consys_reg_util.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_include_emi_mng.h $(PKG_BUILD_DIR)/platform/include/emi_mng.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_include_plat_def.h $(PKG_BUILD_DIR)/platform/include/plat_def.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_include_pmic_mng.h $(PKG_BUILD_DIR)/platform/include/pmic_mng.h
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/platform/mt7981/include
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_include_mt7981.h $(PKG_BUILD_DIR)/platform/mt7981/include/mt7981.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_include_mt7981_consys_reg.h $(PKG_BUILD_DIR)/platform/mt7981/include/mt7981_consys_reg.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_include_mt7981_consys_reg_offset.h $(PKG_BUILD_DIR)/platform/mt7981/include/mt7981_consys_reg_offset.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_include_mt7981_emi.h $(PKG_BUILD_DIR)/platform/mt7981/include/mt7981_emi.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_include_mt7981_pmic.h $(PKG_BUILD_DIR)/platform/mt7981/include/mt7981_pmic.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_include_mt7981_pos.h $(PKG_BUILD_DIR)/platform/mt7981/include/mt7981_pos.h
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/platform/mt7981
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_mt7981.c $(PKG_BUILD_DIR)/platform/mt7981/mt7981.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_mt7981_consys_reg.c $(PKG_BUILD_DIR)/platform/mt7981/mt7981_consys_reg.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_mt7981_emi.c $(PKG_BUILD_DIR)/platform/mt7981/mt7981_emi.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_mt7981_pmic.c $(PKG_BUILD_DIR)/platform/mt7981/mt7981_pmic.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7981_mt7981_pos.c $(PKG_BUILD_DIR)/platform/mt7981/mt7981_pos.c
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/platform/mt7986/include
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_include_mt7986.h $(PKG_BUILD_DIR)/platform/mt7986/include/mt7986.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_include_mt7986_consys_reg.h $(PKG_BUILD_DIR)/platform/mt7986/include/mt7986_consys_reg.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_include_mt7986_consys_reg_offset.h $(PKG_BUILD_DIR)/platform/mt7986/include/mt7986_consys_reg_offset.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_include_mt7986_emi.h $(PKG_BUILD_DIR)/platform/mt7986/include/mt7986_emi.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_include_mt7986_pmic.h $(PKG_BUILD_DIR)/platform/mt7986/include/mt7986_pmic.h
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_include_mt7986_pos.h $(PKG_BUILD_DIR)/platform/mt7986/include/mt7986_pos.h
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/platform/mt7986
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_mt7986.c $(PKG_BUILD_DIR)/platform/mt7986/mt7986.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_mt7986_consys_reg.c $(PKG_BUILD_DIR)/platform/mt7986/mt7986_consys_reg.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_mt7986_emi.c $(PKG_BUILD_DIR)/platform/mt7986/mt7986_emi.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_mt7986_pmic.c $(PKG_BUILD_DIR)/platform/mt7986/mt7986_pmic.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_mt7986_mt7986_pos.c $(PKG_BUILD_DIR)/platform/mt7986/mt7986_pos.c
	$(CP) $(DL_DIR)/conninfra-015af9e-platform_pmic_mng.c $(PKG_BUILD_DIR)/platform/pmic_mng.c
	$(INSTALL_DIR) $(PKG_BUILD_DIR)/src
	$(CP) $(DL_DIR)/conninfra-015af9e-src_conninfra.c $(PKG_BUILD_DIR)/src/conninfra.c
	$(CP) $(DL_DIR)/conninfra-015af9e-src_conninfra_dev.c $(PKG_BUILD_DIR)/src/conninfra_dev.c
endef

# MediaTek's recipe options as GL.iNet set them: APSOC MT7981, EMI support,
# conninfra up by itself, first card's EEPROM file e2p (its Makefile finds
# the headers through SUBDIRS)
CONNINFRA_KCONFIG:=CONFIG_MTK_CONNINFRA_APSOC=y CONFIG_MTK_CONNINFRA_APSOC_MT7981=y \
	CONFIG_CONNINFRA_EMI_SUPPORT=y CONFIG_CONNINFRA_AUTO_UP=y

define Build/Compile
	$(MAKE) -C "$(LINUX_DIR)" ARCH="$(LINUX_KARCH)" CROSS_COMPILE="$(TARGET_CROSS)" M="$(PKG_BUILD_DIR)" \
		SUBDIRS="$(PKG_BUILD_DIR)" \
		KCFLAGS="-fmacro-prefix-map=$(BUILD_DIR)=$(notdir $(BUILD_DIR)) -fno-caller-saves" \
		EXTRA_CFLAGS="-DEEPROM_NAME=e2p $(patsubst %=y,-D%=1,$(CONNINFRA_KCONFIG))" $(CONNINFRA_KCONFIG) modules
	# stripped like OpenWrt's strip-kmod.sh
	$(TARGET_CROSS)objcopy -R .comment -R .pdr -R .mdebug.abi32 -R .gnu.attributes -R .reginfo -R .MIPS.abiflags \
		-R .note.GNU-stack -x -G __this_module --strip-unneeded -R .note.gnu.build-id \
		$(PKG_BUILD_DIR)/conninfra.ko $(PKG_BUILD_DIR)/conninfra.stripped.ko
endef

define Package/kmod-conninfra/install-built
	# over the image's copy, keeping its mode
	cat $(PKG_BUILD_DIR)/conninfra.stripped.ko > $(1)/lib/modules/$(LINUX_VERSION)/conninfra.ko
endef
