################################################################################
#
# sscma-node
#
################################################################################

SSCMA_NODE_VERSION = 0.2.0
SSCMA_NODE_SITE = https://github.com/Seeed-Studio/sscma-example-sg200x
SSCMA_NODE_SITE_METHOD = git
SSCMA_NODE_GIT_SUBMODULES = YES
SSCMA_NODE_LICENSE = Apache-2.0
SSCMA_NODE_DEPENDENCIES = mosquitto libhv alsa-lib recamera-sdk

# Configure step: prepare the build environment and run CMake to configure the build
define SSCMA_NODE_CONFIGURE_CMDS
    mkdir -p $(@D)/solutions/sscma-node/build && \
    cd $(@D)/solutions/sscma-node/build && \
    PATH="$(HOST_DIR)/bin:$$PATH" \
    CC="$(TARGET_CC)" \
    CXX="$(TARGET_CXX)" \
    AR="$(TARGET_AR)" \
    AS="$(TARGET_AS)" \
    LD="$(TARGET_LD)" \
    STRIP="$(TARGET_STRIP)" \
    RANLIB="$(TARGET_RANLIB)" \
    PKG_CONFIG="$(HOST_DIR)/bin/pkg-config" \
    PKG_CONFIG_SYSROOT_DIR="$(STAGING_DIR)" \
    PKG_CONFIG_LIBDIR="$(STAGING_DIR)/usr/lib/pkgconfig:$(STAGING_DIR)/usr/share/pkgconfig" \
    CROSS_COMPILE="$(TARGET_CROSS)" \
    $(BR2_CMAKE) \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_SYSROOT="$(STAGING_DIR)" \
      -DCMAKE_PREFIX_PATH="$(STAGING_DIR)/usr" \
      -DCMAKE_C_FLAGS="$(TARGET_CFLAGS) -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/alsa" \
      -DCMAKE_CXX_FLAGS="$(TARGET_CXXFLAGS) -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/alsa" \
      -DCMAKE_EXE_LINKER_FLAGS="$(TARGET_LDFLAGS) \
        -L$(STAGING_DIR)/usr/lib64/lp64d \
        -L$(STAGING_DIR)/usr/lib \
        -lasound -ldl" \
      -DCMAKE_C_COMPILER="$(TARGET_CC)" \
      -DCMAKE_CXX_COMPILER="$(TARGET_CXX)" \
      -DCMAKE_FIND_ROOT_PATH="$(STAGING_DIR)" \
      -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
      -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
      -DCROSS_COMPILE="$(TARGET_CROSS)" \
      -DSG200X_SDK_PATH="$(RECAMERA_SDK_DIR)" \
      -DSYSROOT="$(STAGING_DIR)" \
      -DCMAKE_INSTALL_PREFIX="$(TARGET_DIR)" \
      ..
endef

# Build step: compile the package using the Makefile in the build directory
define SSCMA_NODE_BUILD_CMDS
    PATH="$(HOST_DIR)/bin:$$PATH" \
    CROSS_COMPILE="$(TARGET_CROSS)" \
    $(MAKE) -C $(@D)/solutions/sscma-node/build VERBOSE=1
endef

# Install step: copy the built files to the target directory
define SSCMA_NODE_INSTALL_TARGET_CMDS
	# Install the executable file to /usr/bin (in PATH)
	$(INSTALL) -D -m 0755 $(@D)/solutions/sscma-node/build/sscma-node $(TARGET_DIR)/usr/bin/sscma-node
	
	# Install SDK shared libraries to target filesystem (musl RISC-V only)
	mkdir -p $(TARGET_DIR)/usr/lib
	
	# Install RISC-V musl libraries from the install tree
	if [ -d "$(RECAMERA_SDK_DIR)/install/soc_sg2002_recamera_emmc/tpu_musl_riscv64" ]; then \
		find $(RECAMERA_SDK_DIR)/install/soc_sg2002_recamera_emmc/tpu_musl_riscv64 -name "*.so*" -type f -exec cp {} $(TARGET_DIR)/usr/lib/ \; ; \
	fi
	
	# Install RISC-V musl libraries from cvi_mpi modules
	if [ -d "$(RECAMERA_SDK_DIR)/cvi_mpi/modules" ]; then \
		find $(RECAMERA_SDK_DIR)/cvi_mpi/modules -path "*/musl_riscv64/*.so*" -type f -exec cp {} $(TARGET_DIR)/usr/lib/ \; ; \
	fi

	# Install core SDK libs from cvi_mpi/lib (filter to RISC-V)
	if [ -d "$(RECAMERA_SDK_DIR)/cvi_mpi/lib" ]; then \
		find $(RECAMERA_SDK_DIR)/cvi_mpi/lib -maxdepth 1 -name "*.so*" -type f -exec file {} \; | grep RISC-V | cut -d: -f1 | xargs -I {} cp {} $(TARGET_DIR)/usr/lib/ ; \
	fi

	# Install libs from the SDK install rootfs tree (filter to RISC-V)
	if [ -d "$(RECAMERA_SDK_DIR)/install/soc_sg2002_recamera_emmc/rootfs/mnt/system/usr/lib" ]; then \
		find $(RECAMERA_SDK_DIR)/install/soc_sg2002_recamera_emmc/rootfs/mnt/system/usr/lib -maxdepth 1 -name "*.so*" -type f -exec file {} \; | grep RISC-V | cut -d: -f1 | xargs -I {} cp {} $(TARGET_DIR)/usr/lib/ ; \
	fi
	
	# Install sensor libraries (check for RISC-V versions)
	if [ -d "$(RECAMERA_SDK_DIR)/buildroot-2021.05/cvi_mmf_sdk/sensors" ]; then \
		find $(RECAMERA_SDK_DIR)/buildroot-2021.05/cvi_mmf_sdk/sensors -name "*.so*" -type f -exec file {} \; | grep RISC-V | cut -d: -f1 | xargs -I {} cp {} $(TARGET_DIR)/usr/lib/ ; \
	fi
	
	# Create OpenCV symlinks for version compatibility
	cd $(TARGET_DIR)/usr/lib && \
	if [ -f libopencv_core.so.3.2.0 ]; then ln -sf libopencv_core.so.3.2.0 libopencv_core.so.3.2; fi && \
	if [ -f libopencv_imgcodecs.so.3.2.0 ]; then ln -sf libopencv_imgcodecs.so.3.2.0 libopencv_imgcodecs.so.3.2; fi && \
	if [ -f libopencv_imgproc.so.3.2.0 ]; then ln -sf libopencv_imgproc.so.3.2.0 libopencv_imgproc.so.3.2; fi
endef

$(eval $(generic-package))