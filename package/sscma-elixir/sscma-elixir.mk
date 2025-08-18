################################################################################
#
# sscma-elixir
#
################################################################################

SSCMA_ELIXIR_VERSION = 51721a4
SSCMA_ELIXIR_SITE = https://github.com/monoflow-ayvu/sscma-elixir
SSCMA_ELIXIR_SITE_METHOD = git
SSCMA_ELIXIR_LICENSE = Apache-2.0

SSCMA_ELIXIR_DEPENDENCIES = libhv alsa-lib recamera-sdk

# Manually clone the repository with all submodules since Buildroot's git handling doesn't work well with submodules
define SSCMA_ELIXIR_EXTRACT_CMDS
	rm -rf $(@D) && \
	git clone --recursive $(SSCMA_ELIXIR_SITE) $(@D) && \
	cd $(@D) && git checkout $(SSCMA_ELIXIR_VERSION)
endef

# Set up environment variables for CMake build
SSCMA_ELIXIR_CONF_ENV = SG200X_SDK_PATH=$(RECAMERA_SDK_DIR)

# CMake configuration options
SSCMA_ELIXIR_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release

# Install the resulting binary into /usr/bin in the target rootfs
define SSCMA_ELIXIR_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/sscma-elixir $(TARGET_DIR)/usr/bin/sscma-elixir
endef

$(eval $(cmake-package))


