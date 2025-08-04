################################################################################
#
# cvitek-fsbl
#
################################################################################

CVITEKFSBL_VERSION = 92735b967c951883c478bae07ca171fa758426c6
CVITEKFSBL_SITE = $(call github,sophgo,fsbl,$(CVITEKFSBL_VERSION))
CVITEKFSBL_LICENSE = GPL-2.0
CVITEKFSBL_DEPENDENCIES = opensbi uboot
CVITEKFSBL_INSTALL_IMAGES = YES


CVITEKFSBL_MAKE_ENV = \
    CROSS_COMPILE=$(TARGET_CROSS) \
		CROSS_COMPILE_GLIBC_RISCV64=$(TARGET_CROSS) \
		CHIP_ARCH=cv181x \
		ARCH=$(BR2_PACKAGE_CVITEKCONFIG_ARCH) \
		DDR_CFG=$(BR2_PACKAGE_CVITEKCONFIG_DDR) \
		FW_DYNAMIC=$(BINARIES_DIR)/fw_dynamic.bin


define CVITEKFSBL_BUILD_CMDS
	$(CVITEKFSBL_MAKE_ENV) $(MAKE) -C $(@D) CFLAGS="-fno-stack-protector" LOADER_2ND_PATH=$(BINARIES_DIR)/u-boot.bin
endef

define CVITEKFSBL_INSTALL_IMAGES_CMDS
	 $(INSTALL) -D -m 0755 $(@D)/build/cv181x/fip.bin $(BINARIES_DIR)/fip.bin
endef

$(eval $(generic-package))
