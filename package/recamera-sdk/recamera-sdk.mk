################################################################################
#
# recamera-sdk
#
################################################################################

RECAMERA_SDK_VERSION = 0.2.0
RECAMERA_SDK_SITE = https://github.com/Seeed-Studio/reCamera-OS/releases/download/$(RECAMERA_SDK_VERSION)
RECAMERA_SDK_SOURCE = reCameraOS_sdk_v$(RECAMERA_SDK_VERSION).tar.gz
RECAMERA_SDK_LICENSE = Proprietary

# Expose the extracted SDK directory for dependent packages
RECAMERA_SDK_DIR = $(BUILD_DIR)/recamera-sdk-$(RECAMERA_SDK_VERSION)

# This package is a pure data SDK drop used by dependent packages during build.
# Nothing to build; no target installation by default.

define RECAMERA_SDK_EXTRACT_CMDS
    # Default extract already handled by Buildroot; keep placeholder in case of special handling later
    true
endef

$(eval $(generic-package))

