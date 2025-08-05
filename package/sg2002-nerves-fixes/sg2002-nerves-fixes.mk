#############################################################
#
# sg2002-nerves-fixes
#
#############################################################

SG2002_NERVES_FIXES_SOURCE =
SG2002_NERVES_FIXES_VERSION = 0.2

SG2002_NERVES_FIXES_DEPENDENCIES =

define SG2002_NERVES_FIXES_INSTALL_TARGET_CMDS
  # toolchain extras
	mkdir -p $(HOST_DIR)/opt/ext-toolchain/bin/
	cp -f $(BR2_EXTERNAL)/package/nerves-config/echo-gcc-args $(BINARIES_DIR)/buildroot-gcc-args
	cp -f $(BR2_EXTERNAL)/package/nerves-config/echo-gcc-args $(HOST_DIR)/opt/ext-toolchain/gcc/riscv64-linux-gnu-x86_64/bin/echo-gcc-args
endef

$(eval $(generic-package))
