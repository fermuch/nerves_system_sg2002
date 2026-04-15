#!/bin/sh

set -e

# Copy the generated U-Boot environment to images directory
if [ -f "$HOST_DIR/bin/mkenvimage" ] && [ -f "$NERVES_DEFCONFIG_DIR/uboot-config/uboot-emmc.env" ]; then
    echo "Generating uboot-env.bin..."
    $HOST_DIR/bin/mkenvimage -s 131072 -o $BINARIES_DIR/uboot-env.bin $NERVES_DEFCONFIG_DIR/uboot-config/uboot-emmc.env
    echo "Generated uboot-env.bin in images directory"
fi

# Run the common post-image processing for nerves
FWUP_CONFIG=$NERVES_DEFCONFIG_DIR/fwup-emmc.conf
$BR2_EXTERNAL_NERVES_PATH/board/nerves-common/post-createfs.sh $TARGET_DIR $FWUP_CONFIG

# nerves-common copies the config by filename (fwup-emmc.conf); application
# firmware builds always look for fwup.conf, so install it under that name too.
cp "$FWUP_CONFIG" "$BINARIES_DIR/fwup.conf"
