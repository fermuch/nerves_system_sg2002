# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a custom Nerves system for SG2002-based single-board computers (like reCamera) powered by the Sophgo SG2002 SoC. It's a Buildroot-based system that creates bootable Linux images for running Elixir applications on RISC-V 64-bit embedded devices.

**Key Technologies:**
- Architecture: RISC-V 64-bit (`riscv64`) with `lp64d` ABI
- Kernel: Sophgo Linux 5.10
- Bootloader: Sophgo U-Boot 2021.10
- Toolchain: Musl-based (external Sophgo toolchain)
- Init system: None (BR2_INIT_NONE) - Nerves handles initialization

## Build Commands

### Using Nix (recommended)
```bash
# Enter development shell
devenv shell

# Build firmware
MIX_TARGET=nerves_system_sg2002 mix deps.get
MIX_TARGET=nerves_system_sg2002 mix firmware

# Burn to SD card
MIX_TARGET=nerves_system_sg2002 mix firmware.burn
```

### Using Docker (for CI/release builds)
The system uses Docker for reproducible builds. The Dockerfile (`Dockerfile`) defines the build environment with Erlang/OTP 28 and Elixir 1.18.

```bash
# Build inside Docker container
mix firmware
```

## Architecture

### Directory Structure
- `board/` - Board-specific configurations (device trees, defconfigs, rootfs overlays)
- `boot/` - Bootloader build definitions (cvitekfsbl)
- `package/` - Custom Buildroot packages (cvitek modules, cloudutils, sscma, etc.)
- `patches/` - Buildroot patches applied during build
- `rootfs-overlay/` - Files overlaid onto the root filesystem
- `fwup_include/` - fwup configuration fragments
- `uboot/` - U-Boot configuration and environment
- `generated/` - Generated configuration files

### Partition Layout (fwup.conf)
A/B partition scheme for OTA updates:
1. **Boot** (16 MiB, FAT16) - Boot files at offset 16384
2. **Rootfs A** (256 MiB, squashfs) - Active root filesystem
3. **Rootfs B** (256 MiB, squashfs) - Inactive slot for OTA updates
4. **Data** (512+ MiB, ext4) - Application data, grows to fill SD card

Special raw writes:
- FIP/U-Boot at block offset 66
- U-Boot environment at block offset 8192

### Build Flow
1. `mix.exs` configures Nerves package with Docker build runner
2. Buildroot uses `nerves_defconfig` as the main configuration
3. `external.mk` includes all `package/*/*.mk` and `boot/*/*.mk` files
4. `post-build.sh` generates fwup ops.fw and copies Erlang libs
5. `post-createfs.sh` creates U-Boot environment and calls nerves-common post-createfs

### Custom Buildroot Packages
Located in `package/`:
- `cvitekconfig` - Board configuration (chip, storage, panel, ION heap sizes)
- `cvitek-modules` - Kernel modules for SG2002
- `cvitek-oss` - Open source components
- `sscma-node` / `sscma-elixir` - TPU/Camera ML support
- `cloudutils` - Cloud connectivity utilities
- `aic-firmware` - WiFi firmware (AIC wireless)

## Configuration Files

- `nerves_defconfig` - Main Buildroot configuration (toolchain, kernel, packages)
- `fwup.conf` - Firmware update configuration (partition layout, upgrade tasks)
- `fwup-ops.conf` - Runtime operations (factory reset, data partition operations)
- `fwup_include/fwup-common.conf` - Shared fwup definitions (partition offsets, metadata)
- `fwup_include/provisioning.conf` - Device provisioning settings
- `uboot/uboot.defconfig` - U-Boot configuration
- `uboot/uboot.env` - U-Boot environment defaults

## Target Device

- Device path: `/dev/mmcblk1` (MicroSD)
- Application partition: `/dev/mmcblk1p4` (mounted at `/root`)
- Hostname: `recamera`
- Platform: `sg2002`
- Architecture: `riscv`

## Modifying the System

### Adding Buildroot packages
1. Create directory in `package/<name>/`
2. Create `<name>.mk` following Buildroot conventions
3. Create `Config.in` for package options
4. The package is auto-included via `external.mk`

### Changing partition layout
Edit `fwup_include/fwup-common.conf` for offset/count changes, then update `fwup.conf` if partition structure changes.

### Adding kernel modules/config
Edit `nerves_defconfig` or create patches in `patches/` directory.

### Updating U-Boot environment
Edit `uboot/uboot.env` - this gets compiled to `uboot-env.bin` during build.
