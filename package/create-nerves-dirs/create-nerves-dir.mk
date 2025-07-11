#############################################################
#
# create-nerves-dirs
#
#############################################################

CREATE_NERVES_DIRS_SOURCE =
CREATE_NERVES_DIRS_VERSION = 0.2

CREATE_NERVES_DIRS_DEPENDENCIES =

define CREATE_NERVES_DIRS_INSTALL_TARGET_CMDS
  # scripts for after building the firmware
	mkdir -p $(BASE_DIR)/scripts
	cp -r $(NERVES_DEFCONFIG_DIR)/deps/nerves_system_br/scripts/* $(BASE_DIR)/scripts/
  # toolchain extras
	mkdir -p $(HOST_DIR)/opt/ext-toolchain/bin/
	cp -f $(BR2_EXTERNAL)/package/nerves-config/echo-gcc-args $(BINARIES_DIR)/buildroot-gcc-args
	cp -f $(BR2_EXTERNAL)/package/nerves-config/echo-gcc-args $(HOST_DIR)/opt/ext-toolchain/gcc/riscv64-linux-musl-x86_64/bin/echo-gcc-args
endef

$(eval $(generic-package))
