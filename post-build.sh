#!/usr/bin/env bash

set -e

# Create the fwup ops script to handling MicroSD/eMMC operations at runtime
# NOTE: revert.fw is the previous, more limited version of this. ops.fw is
#       backwards compatible.
mkdir -p $TARGET_DIR/usr/share/fwup
$HOST_DIR/usr/bin/fwup -c -f $NERVES_DEFCONFIG_DIR/fwup-ops.conf -o $TARGET_DIR/usr/share/fwup/ops.fw
ln -sf ops.fw $TARGET_DIR/usr/share/fwup/revert.fw

# Copy the fwup includes to the images dir
cp -rf $NERVES_DEFCONFIG_DIR/fwup_include $BINARIES_DIR

# Expose Erlang ERTS libs to dynamic linker: link EI libs into /usr/lib if present
if [ -d "$TARGET_DIR/srv/erlang" ]; then
  ERTS_DIR=$(find "$TARGET_DIR/srv/erlang" -maxdepth 1 -type d -name 'erts-*' | head -n 1)
  if [ -n "$ERTS_DIR" ] && [ -d "$ERTS_DIR/lib" ]; then
    mkdir -p "$TARGET_DIR/usr/lib"
    for libpat in libei.so* liberl_interface.so*; do
      for src in "$ERTS_DIR/lib"/$libpat; do
        [ -f "$src" ] || continue
        cp -a "$src" "$TARGET_DIR/usr/lib/" || true
      done
    done
  fi
fi

# Provide an ldd helper on musl systems for debugging
mkdir -p "$TARGET_DIR/usr/bin"
cat > "$TARGET_DIR/usr/bin/ldd" <<'SH'
#!/bin/sh
ARCH=$(uname -m)
LD_SO="/lib/ld-musl-${ARCH}.so.1"
if [ ! -x "$LD_SO" ]; then
  for so in /lib/ld-musl-*.so.1; do
    [ -x "$so" ] && LD_SO="$so" && break
  done
fi
exec "$LD_SO" --list "$@"
SH
chmod +x "$TARGET_DIR/usr/bin/ldd"
