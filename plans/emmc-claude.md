# Plan: eMMC Boot Support for SG2002 reCamera

## Context

The Nerves system currently boots exclusively from the MicroSD card (`/dev/mmcblk1`). The reCamera hardware has an internal eMMC chip connected to a dedicated controller at `0x4300000`, which Linux enumerates as `/dev/mmcblk0`. The eMMC controller is already defined in the device tree (`cv181x_base.dtsi:482-497`) and is **not** disabled by the board DTS — meaning the kernel already probes it. The goal is to support installing and booting the Nerves firmware from eMMC instead of SD.

**Hardware facts:**
- eMMC controller @ `0x4300000` → `mmcblk0` (non-removable, probed first)
- SD controller @ `0x4310000` → `mmcblk1` (removable, card-detect GPIO on porta 13)
- SG2002 ROM boot order: SD first, then eMMC. Device boots from eMMC when no SD card is inserted.
- reCamera eMMC is 8 GiB; current partition layout needs ~536 MiB minimum — fits easily.

**Approach:** Create parallel eMMC configuration files alongside the existing SD ones, selected at build time via an environment variable. No existing SD files are modified (except minor fixes). This is the standard Nerves pattern for board variants.

---

## Changes Overview

The difference between SD and eMMC boot is fundamentally: **mmcblk1 → mmcblk0** and **devnum=1 → devnum=0** across ~12 configuration files. Everything else (partition layout, sizes, kernel, packages) is identical.

---

## Phase 1: Device Tree

### 1.1 Create `board/sipeed/recamera/dts/sg2002_recamera_emmc.dts`

Copy `sg2002_recamera_sd.dts` with two changes:
- Line 82: `model = "Seeed reCamera (eMMC)";`
- Line 102: `linux,default-trigger = "mmc0";` (activity LED follows eMMC instead of SD)

The eMMC controller is already enabled in the base DTSI — no additional DTS changes needed.

---

## Phase 2: FIT Image

### 2.1 Create `board/sipeed/recamera/fit-image-emmc.its`

Copy `board/sipeed/recamera/fit-image.its` with:
- Line 29: `data = /incbin/("./sg2002_recamera_emmc.dtb");`
- Line 41: `default = "config-sg2002_recamera_emmc";`
- Line 43-44: config name → `config-sg2002_recamera_emmc`, description updated

### 2.2 Create `board/sipeed/recamera/genimage-emmc.cfg`

Copy `board/sipeed/recamera/genimage.cfg` with:
- `boot.sd` → `boot.emmc` in the vfat files list
- `sdcard.img` → `emmc.img` as the output image name

### 2.3 Create `board/sipeed/recamera/postinstall-emmc.sh`

Copy `board/sipeed/recamera/postinstall.sh` with:
- Line 9: copy `fit-image-emmc.its` instead of `fit-image.its`
- Line 10: output `boot.emmc` instead of `boot.sd`
- Line 12: use `genimage-emmc.cfg` instead of `genimage.cfg`

---

## Phase 3: U-Boot Configuration

### 3.1 Create `uboot-config/uboot-emmc.defconfig`

Copy `uboot-config/uboot.defconfig` with:
- `CONFIG_DEFAULT_DEVICE_TREE="sg2002_recamera_emmc"` (line 5)
- `CONFIG_SYS_MMC_ENV_DEV=0` (was `1`, line 46)

### 3.2 Create `uboot-config/uboot-emmc.env`

Copy `uboot-config/uboot.env` with these changes:
- Line 23: `devnum=0`
- Line 39: `rootfs_a=/dev/mmcblk0p2`
- Line 40: `rootfs_b=/dev/mmcblk0p3`
- Line 83: `bootfile=boot.emmc`
- Line 84: `fdtfile=/boot/sg2002_recamera_emmc.dtb`
- Line 94: `bootm 0x81800000#config-sg2002_recamera_emmc`

---

## Phase 4: fwup Configuration

### 4.1 Create `fwup_include/fwup-common-emmc.conf`

Copy `fwup_include/fwup-common.conf` with:
- Line 2 comment: `eMMC on /dev/mmcblk0`
- Line 13: `define(NERVES_FW_DEVPATH, "/dev/mmcblk0")`
- Line 14: `define(NERVES_FW_APPLICATION_PART0_DEVPATH, "/dev/mmcblk0p4")`

Partition geometry (offsets, sizes) stays identical.

### 4.2 Create `fwup-emmc.conf`

Copy `fwup.conf` with:
- Line 6: `include("${NERVES_SDK_IMAGES:-.}/fwup_include/fwup-common-emmc.conf")`

### 4.3 Create `fwup-ops-emmc.conf`

Copy `fwup-ops.conf` with:
- Line 6: include `fwup-common-emmc.conf`
- Lines 84-87: `mmcblk1p2` → `mmcblk0p2`, `mmcblk1p3` → `mmcblk0p3`

---

## Phase 5: Root Filesystem Overlay

### 5.1 Create `rootfs-overlay-emmc/` directory

Contains only the files that differ from the SD overlay. Buildroot applies overlays in order, so eMMC-specific files override SD ones.

### 5.2 `rootfs-overlay-emmc/etc/erlinit.config`

Copy from `rootfs-overlay/etc/erlinit.config` with:
- Line 67: `-m /dev/mmcblk0p1:/boot:vfat:ro,nodev,noexec,nosuid:`
- Line 68: `-m /dev/mmcblk0p4:/root:ext4:nodev:`

### 5.3 `rootfs-overlay-emmc/etc/fstab`

Copy from `rootfs-overlay/etc/fstab` with:
- Line 9: `/dev/mmcblk0p1  /boot  vfat  defaults  0  0`

### 5.4 `rootfs-overlay-emmc/etc/fw_env.config`

Copy from `rootfs-overlay/etc/fw_env.config` with:
- `/dev/mmcblk0  0x400000  0x20000  0x200  256`

### 5.5 `rootfs-overlay-emmc/etc/init.d/S01growfs`

Create a no-op version (just `exit 0`). The original S01growfs tries to resize a squashfs partition, which is wrong for Nerves. Nerves' `nerves_runtime` handles data partition management.

---

## Phase 6: Build Scripts

### 6.1 Create `post-build-emmc.sh`

Copy `post-build.sh` with:
- Line 9: compile `fwup-ops-emmc.conf` instead of `fwup-ops.conf`

### 6.2 Create `post-createfs-emmc.sh`

Copy `post-createfs.sh` with:
- Line 35: `FWUP_CONFIG=$NERVES_DEFCONFIG_DIR/fwup-emmc.conf`

---

## Phase 7: Buildroot Defconfig

### 7.1 Create `nerves_defconfig_emmc`

Copy `nerves_defconfig` with these changes:

| Line | Setting | SD value | eMMC value |
|------|---------|----------|------------|
| 44 | `BR2_LINUX_KERNEL_CUSTOM_DTS_PATH` | `sg2002_recamera_sd.dts` | `sg2002_recamera_emmc.dts` |
| 127 | `BR2_ROOTFS_OVERLAY` | `...rootfs-overlay` | `...rootfs-overlay ${NERVES_DEFCONFIG_DIR}/rootfs-overlay-emmc` |
| 128 | `BR2_ROOTFS_POST_BUILD_SCRIPT` | `post-build.sh` | `post-build-emmc.sh` |
| 129 | `BR2_ROOTFS_POST_IMAGE_SCRIPT` | `post-createfs.sh ... postinstall.sh` | `post-createfs-emmc.sh ... postinstall-emmc.sh` |
| 140 | `BR2_TARGET_UBOOT_CUSTOM_MAKEOPTS` | `CVIBOARD=recamera_sd ... STORAGE_TYPE=sd` | `CVIBOARD=recamera_sd ... STORAGE_TYPE=emmc` |
| 142 | `BR2_TARGET_UBOOT_CUSTOM_CONFIG_FILE` | `uboot.defconfig` | `uboot-emmc.defconfig` |
| 153 | `BR2_PACKAGE_HOST_UBOOT_TOOLS_ENVIMAGE_SOURCE` | `uboot.env` | `uboot-emmc.env` |

**Note:** `CVIBOARD` stays `recamera_sd` because it selects pin muxing/board init code which is identical regardless of boot device. Only `STORAGE_TYPE` changes to `emmc`.

---

## Phase 8: mix.exs Integration

### 8.1 Modify `mix.exs`

Add environment variable support to select the defconfig:

```elixir
defp nerves_package do
  storage = System.get_env("NERVES_STORAGE", "sd")
  defconfig = if storage == "emmc", do: "nerves_defconfig_emmc", else: "nerves_defconfig"
  [
    ...
    platform_config: [defconfig: defconfig],
    ...
  ]
end
```

### 8.2 Update `package_files/0` in `mix.exs`

Add to the list:
- `"rootfs-overlay-emmc"`
- `"fwup-emmc.conf"`
- `"fwup-ops-emmc.conf"`
- `"nerves_defconfig_emmc"`
- `"post-build-emmc.sh"`
- `"post-createfs-emmc.sh"`

---

## Phase 9: SD-to-eMMC Flashing Mechanism

The eMMC `.fw` file is a standard fwup firmware archive. To flash it onto eMMC from a running SD-based system:

```bash
# From IEx on the SD-booted device:
# 1. Upload emmc.fw to the device (via SSH/SCP to /tmp/)
# 2. Flash it:
cmd("fwup -a -d /dev/mmcblk0 -i /tmp/nerves_system_sg2002_emmc.fw -t complete")
# 3. Remove SD card and reboot — device boots from eMMC
```

No code changes needed for this — fwup already supports writing to arbitrary block devices. The eMMC `.fw` file contains the correct mmcblk0 device paths baked into its U-Boot environment.

---

## Phase 10: Bug Fix — S01growfs on SD build

The current `rootfs-overlay/etc/init.d/S01growfs` references `/dev/mmcblk0` (eMMC) even in the SD build. It tries to `parted resizepart` on a squashfs partition, which is wrong for Nerves. This is harmless (Nerves uses BR2_INIT_NONE so SysV init scripts don't run), but should be cleaned up.

**Action:** Make S01growfs a no-op in the SD build too, or delete it. `nerves_runtime` handles data partition management.

---

## Files Summary

**New files (15):**
- `board/sipeed/recamera/dts/sg2002_recamera_emmc.dts`
- `board/sipeed/recamera/fit-image-emmc.its`
- `board/sipeed/recamera/genimage-emmc.cfg`
- `board/sipeed/recamera/postinstall-emmc.sh`
- `uboot-config/uboot-emmc.defconfig`
- `uboot-config/uboot-emmc.env`
- `fwup_include/fwup-common-emmc.conf`
- `fwup-emmc.conf`
- `fwup-ops-emmc.conf`
- `rootfs-overlay-emmc/etc/erlinit.config`
- `rootfs-overlay-emmc/etc/fstab`
- `rootfs-overlay-emmc/etc/fw_env.config`
- `rootfs-overlay-emmc/etc/init.d/S01growfs`
- `post-build-emmc.sh`
- `post-createfs-emmc.sh`
- `nerves_defconfig_emmc`

**Modified files (1):**
- `mix.exs` — add `NERVES_STORAGE` env var support + new package files

---

## Build & Test

```bash
# Build eMMC firmware
NERVES_STORAGE=emmc MIX_TARGET=nerves_system_sg2002 mix deps.get
NERVES_STORAGE=emmc MIX_TARGET=nerves_system_sg2002 mix firmware

# Build SD firmware (unchanged)
MIX_TARGET=nerves_system_sg2002 mix firmware

# Flash eMMC from running SD system
scp _build/nerves_system_sg2002_dev/nerves/images/nerves_system_sg2002.fw user@device:/tmp/emmc.fw
# On device IEx:
cmd("fwup -a -d /dev/mmcblk0 -i /tmp/emmc.fw -t complete")
# Remove SD card, reboot
```

## Risks

1. **CVIBOARD validation**: If Sophgo U-Boot requires `CVIBOARD=recamera_emmc` (not just `STORAGE_TYPE=emmc`), the U-Boot build may need adjustment. Mitigation: we keep `CVIBOARD=recamera_sd` since pin muxing is identical; only `STORAGE_TYPE` changes.

2. **Boot ROM SD priority**: The SG2002 ROM tries SD before eMMC. If a user leaves an SD card inserted after flashing eMMC, the SD card boots instead. This is expected behavior — document it clearly.

3. **MMC device numbering**: We rely on eMMC being `mmcblk0` and SD being `mmcblk1`. This is stable because the eMMC node has a lower hardware address and `non-removable` property, ensuring it probes first. However, if the eMMC DTS node were ever disabled, SD would become `mmcblk0`.
