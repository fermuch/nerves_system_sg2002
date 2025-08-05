#!/bin/sh

set -e

# Copy the generated U-Boot environment to images directory
if [ -f "$HOST_DIR/bin/mkenvimage" ] && [ -f "$NERVES_DEFCONFIG_DIR/uboot/uboot.env" ]; then
    echo "Generating uboot-env.bin..."
    $HOST_DIR/bin/mkenvimage -s 131072 -o $BINARIES_DIR/uboot-env.bin $NERVES_DEFCONFIG_DIR/uboot/uboot.env
    echo "Generated uboot-env.bin in images directory"
fi

# Create boot.vfat
# if [ -f "$BINARIES_DIR/fip.bin" ] && [ -f "$BINARIES_DIR/boot.sd" ] && [ -f "$BINARIES_DIR/uboot-env.bin" ]; then
#     echo "Creating boot.vfat image..."
    
#     # Create temporary directory for boot files
#     BOOT_DIR=$(mktemp -d)
#     cp $BINARIES_DIR/fip.bin $BOOT_DIR/
#     cp $BINARIES_DIR/boot.sd $BOOT_DIR/
#     cp $BINARIES_DIR/uboot-env.bin $BOOT_DIR/
    
#     # Create 16MB FAT32 image
#     $HOST_DIR/sbin/mkfs.fat -C -F 32 -n "boot" $BINARIES_DIR/boot.vfat 16384
    
#     # Copy files into the FAT image
#     $HOST_DIR/bin/mcopy -i $BINARIES_DIR/boot.vfat $BOOT_DIR/* ::/
    
#     # Cleanup
#     rm -rf $BOOT_DIR
    
#     echo "Generated boot.vfat image"
# fi

# Run the common post-image processing for nerves
FWUP_CONFIG=$NERVES_DEFCONFIG_DIR/fwup.conf
$BR2_EXTERNAL_NERVES_PATH/board/nerves-common/post-createfs.sh $TARGET_DIR $FWUP_CONFIG
