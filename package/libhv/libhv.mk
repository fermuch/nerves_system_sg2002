################################################################################
#
# libhv
#
################################################################################

LIBHV_VERSION = v1.3.3
LIBHV_SOURCE = $(LIBHV_VERSION).tar.gz
LIBHV_SITE = https://github.com/ithewei/libhv/archive/refs/tags
LIBHV_DEPENDENCIES = openssl c-ares
LIBHV_INSTALL_STAGING = YES

define LIBHV_CONFIGURE_CMDS
    (cd $(@D); $(TARGET_CONFIGURE_OPTS) ./configure --with-mqtt --with-openssl --with-cares)
endef

define LIBHV_BUILD_CMDS
	$(TARGET_CONFIGURE_OPTS) $(MAKE) libhv -C $(@D)
endef

define LIBHV_INSTALL_TARGET_CMDS
	cp -rf $(@D)/lib/* $(TARGET_DIR)/usr/lib/
endef

define LIBHV_INSTALL_STAGING_CMDS
	cp -rf $(@D)/lib/* $(STAGING_DIR)/usr/lib/
	cp -rf $(@D)/include/* $(STAGING_DIR)/usr/include/
endef

$(eval $(generic-package))