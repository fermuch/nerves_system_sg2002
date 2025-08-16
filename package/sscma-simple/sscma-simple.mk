################################################################################
#
# sscma-simple
#
################################################################################

SSCMA_SIMPLE_VERSION = 0.1.1
SSCMA_SIMPLE_SITE = $(NERVES_DEFCONFIG_DIR)/package/sscma-simple
SSCMA_SIMPLE_SITE_METHOD = local
SSCMA_SIMPLE_LICENSE = Apache-2.0

# We don't need mosquitto. Keep deps minimal. Pull in SDK only if you plan to use it.
SSCMA_SIMPLE_DEPENDENCIES = libhv alsa-lib recamera-sdk sscma-node json-for-modern-cpp mosquitto

# Build a single C++ file into `sscma-simple` binary using cross toolchain
define SSCMA_SIMPLE_BUILD_CMDS
	$(TARGET_CXX) \
		$(TARGET_CXXFLAGS) -std=c++17 -O2 -pipe \
		-I$(STAGING_DIR)/usr/include \
		-I$(STAGING_DIR)/usr/include/alsa \
		-I$(RECAMERA_SDK_DIR)/buildroot-2021.05/output/cvitek_CV181X_musl_riscv64/host/riscv64-buildroot-linux-musl/sysroot/usr/include \
		-I$(RECAMERA_SDK_DIR)/install/soc_sg2002_recamera_emmc/tpu_musl_riscv64/cvitek_tpu_sdk/include \
		-I$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/components/sscma-micro/sscma-micro/sscma \
		-I$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/components/sscma-micro/porting/sophgo \
		-I$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/components/sscma-micro/porting/sophgo/sg200x \
		-I$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/components/sscma-micro/porting/sophgo/sg200x/recamera \
		-I$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/components/sscma-micro/sscma-micro/3rdparty/json/cJSON \
		-I$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/components/sscma-micro/sscma-micro/3rdparty/eigen \
		-I$(RECAMERA_SDK_DIR)/cvi_mpi/include \
		-I$(RECAMERA_SDK_DIR)/cvi_mpi/include/isp/cv181x \
		-I$(RECAMERA_SDK_DIR)/cvi_mpi/modules/isp/include/cv181x \
		-I$(RECAMERA_SDK_DIR)/osdrv/interdrv/v2/include/common/uapi \
		-I$(LINUX_DIR)/include \
		-I$(LINUX_DIR)/usr/include \
		-I$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/components/sophgo/video \
		-I$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/components/sophgo/video/include \
		-I$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/components/sophgo/common \
		-o $(@D)/sscma-simple \
		$(@D)/src/main.cpp \
		$(TARGET_LDFLAGS) \
		-L$(STAGING_DIR)/usr/lib64/lp64d \
		-L$(STAGING_DIR)/usr/lib \
		-L$(RECAMERA_SDK_DIR)/buildroot-2021.05/output/cvitek_CV181X_musl_riscv64/host/riscv64-buildroot-linux-musl/sysroot/usr/lib \
		-L$(RECAMERA_SDK_DIR)/install/soc_sg2002_recamera_emmc/tpu_musl_riscv64/cvitek_tpu_sdk/lib \
		-L$(RECAMERA_SDK_DIR)/install/soc_sg2002_recamera_emmc/rootfs/mnt/system/lib \
		-L$(RECAMERA_SDK_DIR)/cvi_mpi/lib \
		-L$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/solutions/sscma-node/build \
		-L$(BUILD_DIR)/sscma-node-$(SSCMA_NODE_VERSION)/solutions/sscma-node/build/lib \
		-lasound -ldl -lopencv_core -lopencv_imgproc -lopencv_imgcodecs \
		-lmain -lsscma-micro -lsophgo -lcviruntime -lcares -lhv -lcvi_rtsp -lcrypto -lssl -lmosquitto \
		-lsys -lvpss -lvenc -lvi -lvo -lisp -lisp_algo -lgdc -lcvi_bin -lcvi_bin_isp -lae -laf -lawb -latomic -lcvi_ispd2 -ljson-c -lsns_ov5647 -lsns_sc530ai_2l
endef

# Install the resulting binary into /usr/bin in the target rootfs
define SSCMA_SIMPLE_INSTALL_TARGET_CMDS
	# Install binary
	$(INSTALL) -D -m 0755 $(@D)/sscma-simple $(TARGET_DIR)/usr/bin/sscma-simple

	# Ensure SDK shared libraries are present on target (musl RISC-V only)
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

	# Sensor libraries (RISC-V)
	if [ -d "$(RECAMERA_SDK_DIR)/buildroot-2021.05/cvi_mmf_sdk/sensors" ]; then \
		find $(RECAMERA_SDK_DIR)/buildroot-2021.05/cvi_mmf_sdk/sensors -name "*.so*" -type f -exec file {} \; | grep RISC-V | cut -d: -f1 | xargs -I {} cp {} $(TARGET_DIR)/usr/lib/ ; \
	fi

	# OpenCV symlinks for compatibility
	cd $(TARGET_DIR)/usr/lib && \
	if [ -f libopencv_core.so.3.2.0 ]; then ln -sf libopencv_core.so.3.2.0 libopencv_core.so.3.2; fi && \
	if [ -f libopencv_imgcodecs.so.3.2.0 ]; then ln -sf libopencv_imgcodecs.so.3.2.0 libopencv_imgcodecs.so.3.2; fi && \
	if [ -f libopencv_imgproc.so.3.2.0 ]; then ln -sf libopencv_imgproc.so.3.2.0 libopencv_imgproc.so.3.2; fi
endef

$(eval $(generic-package))


