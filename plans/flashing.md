# eMMC Build & Flash Testing Guide

## Step 1: Build the eMMC firmware

```bash
NERVES_STORAGE=emmc MIX_TARGET=nerves_system_sg2002 mix deps.get
NERVES_STORAGE=emmc MIX_TARGET=nerves_system_sg2002 mix firmware
```

Before booting anything, sanity-check the output:

```bash
# Verify device paths are mmcblk0, not mmcblk1
# fwup compiles the config into meta.conf inside the .fw archive
unzip -p _build/nerves_system_sg2002_dev/nerves/images/example.fw meta.conf | grep mmcblk

# Verify U-Boot env has devnum=0
strings ~/.local/share/nerves/artifacts/nerves_system_sg2002-portable-1.4.0/images/uboot-env.bin \
  | grep -E "devnum|mmcblk|bootfile|config-sg"
```

Expected: `mmcblk0` in the meta.conf output; `devnum=0`, `mmcblk0p*`, `boot.emmc`, `config-sg2002_recamera_emmc` in the uboot env.

---

## Step 2: Flash eMMC from a running SD system

Boot the device from SD (existing build), then:

```bash
# From your machine — copy the .fw to the device
scp _build/nerves_system_sg2002_dev/nerves/images/nerves_system_sg2002.fw root@<device-ip>:/tmp/emmc.fw
```

Then from IEx on the device:

```elixir
cmd("fwup -a -d /dev/mmcblk0 -i /tmp/emmc.fw -t complete")
```

---

## Step 3: Boot from eMMC

1. **Power off** the device
2. **Remove the SD card**
3. Power back on — it should boot from eMMC

Watch the serial console (`ttyS0`, 115200 baud) during boot. Key things to verify:

- U-Boot prompt shows `mmc dev 0` (not `1`)
- Kernel mounts `/dev/mmcblk0p1` as `/boot`
- Nerves comes up and `/dev/mmcblk0p4` is mounted at `/root`

From IEx after boot:

```elixir
# Confirm we're on mmcblk0
File.read!("/etc/fw_env.config")   # should show mmcblk0
cmd("mount | grep mmcblk")          # should show mmcblk0p1, mmcblk0p4

# Confirm firmware metadata
cmd("fw_printenv nerves_fw_devpath")   # /dev/mmcblk0
cmd("fw_printenv devnum")              # 0
```

---

## Risks to watch for

| Symptom | Likely cause |
|---|---|
| U-Boot hangs on `mmc dev 0` | eMMC not probing — check DTS or STORAGE_TYPE |
| Kernel panic: can't mount root | Wrong rootfs partition path in U-Boot env |
| Boots from SD instead of eMMC | SD card still inserted (ROM tries SD first) |
| `fwup` flash fails mid-write | eMMC write-protected or wrong block device |
