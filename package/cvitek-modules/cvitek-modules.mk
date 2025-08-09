################################################################################
#
# cvitek-modules
#
################################################################################

CVITEK_MODULES_VERSION = f35ca075cc022aac97f5d22238c1e46caf8276bd
CVITEK_MODULES_SITE = $(call github,sophgo,osdrv,$(CVITEK_MODULES_VERSION))
CVITEK_MODULES_LICENSE = GPL-2.0(kernel driver), Apache 2.0(userspace)
CVITEK_MODULES_INSTALL_STAGING = YES

CVITEK_MODULES_MODULE_MAKE_OPTS = \
    CHIP_CODE=CV181X CVIARCH=CV181X CHIP_ARCH=CV181X CVIARCH_L=cv181x \
    CHIP=cv181x CHIP_CODE=cv181x CVIARCH=cv181x CHIP_ARCH=cv181x \
    EXTRA_CFLAGS=-D__CV181X__\ \
                 -I$(BUILD_DIR)/cvitek-modules-$(CVITEK_MODULES_VERSION)/interdrv/include\ \
                 -I$(BUILD_DIR)/cvitek-modules-$(CVITEK_MODULES_VERSION)/interdrv/include/common/uapi\ \
                 -I$(BUILD_DIR)/cvitek-modules-$(CVITEK_MODULES_VERSION)/interdrv/include/chip/cv181x/uapi

CVITEK_MODULES_MODULE_SUBDIRS = interdrv/sys 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/base 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/vcodec 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/jpeg 
# CVITEK_MODULES_MODULE_SUBDIRS += interdrv/pwm 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/rtc 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/wdt 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/tpu 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/mon 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/clock_cooling 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/saradc 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/wiegand 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/vi 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/snsr_i2c 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/cif
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/vpss 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/dwa 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/rgn 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/vo 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/rtos_cmdqu 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/fast_image 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/cvi_vc_drv 
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/ive
CVITEK_MODULES_MODULE_SUBDIRS += interdrv/fb
# CVITEK_MODULES_MODULE_SUBDIRS += extdrv/tp/ts_gsl
# CVITEK_MODULES_MODULE_SUBDIRS += extdrv/tp/ts_gt9xx
# CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wiegand-gpio
# #CVITEK_MODULES_MODULE_SUBDIRS += extdrv/gyro_i2c
# #CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wireless/broadcom/bcmdhd
# #CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wireless/icommsemi/sv6115
# #CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wireless/mediatek/mt7603
# #CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wireless/realtek/rtl8188f
# #CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wireless/realtek/rtl8189fs
# #CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wireless/realtek/rtl8723ds
# #CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wireless/realtek/rtl8821cs
# CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wireless/aic8800/

 

# CVITEK_MODULES_MODULE_SUBDIRS += extdrv/gyro_i2c
# CVITEK_MODULES_MODULE_SUBDIRS += extdrv/motor
CVITEK_MODULES_MODULE_SUBDIRS += extdrv/tp/ts_gsl
CVITEK_MODULES_MODULE_SUBDIRS += extdrv/tp/ts_gt9xx
# CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wiegand-gpio
# CVITEK_MODULES_MODULE_SUBDIRS += extdrv/wireless/broadcom/bcmdhd

define CVITEK_MODULES_INSTALL_STAGING_CMDS
    $(INSTALL) -D -m 0644 $(@D)/interdrv/include/common/uapi/linux/* $(LINUX_DIR)/usr/include/linux/
    $(INSTALL) -D -m 0644 $(@D)/interdrv/include/chip/cv181x/uapi/linux/* $(LINUX_DIR)/usr/include/linux/
    $(info Staging Directory = $(STAGING_DIR))
endef


$(eval $(kernel-module))
$(eval $(generic-package))
