#!/bin/bash
set -euo pipefail
echo "Creating Filesystem Image"

SCRIPTS_DIR=$PWD/support/scripts

cd $BINARIES_DIR
rm emmc.img || true
cp $NERVES_DEFCONFIG_DIR/board/sipeed/recamera/fit-image-emmc.its $BINARIES_DIR/fit-image-emmc.its
$BINARIES_DIR/../host/bin/mkimage -f fit-image-emmc.its $BINARIES_DIR/boot.emmc
echo "Creating Filesystem Image"
$SCRIPTS_DIR/genimage.sh -c $NERVES_DEFCONFIG_DIR/board/sipeed/recamera/genimage-emmc.cfg
echo "Completed - Images are at $BINARIES_DIR"
