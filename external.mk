# Include system-specific packages

include $(sort $(wildcard $(NERVES_DEFCONFIG_DIR)/package/*/*.mk))
include $(sort $(wildcard $(NERVES_DEFCONFIG_DIR)/boot/*/*.mk))
