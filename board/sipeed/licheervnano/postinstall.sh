#!/bin/bash
set -euo pipefail
echo "Creating Filesystem Image"

SCRIPTS_DIR=$PWD/support/scripts

cd $BINARIES_DIR
rm sdcard.img || true
cp $NERVES_DEFCONFIG_DIR/board/sipeed/licheervnano/fit-image.its $BINARIES_DIR/fit-image.its
$BINARIES_DIR/../host/bin/mkimage -f fit-image.its $BINARIES_DIR/boot.sd
echo "Creating Filesystem Image"
$SCRIPTS_DIR/genimage.sh -c $NERVES_DEFCONFIG_DIR/board/sipeed/licheervnano/genimage.cfg
echo "Completed - Images are at $BINARIES_DIR"
