## v2.0.0

Expanded the A/B partition layout for the 8 GB minimum target media:

* Rootfs A/B slots grown from 256 MiB to 1.5 GiB (room for ML models in
  the firmware image).
* Data partition minimum raised to 1 GiB (still expands to fill the card).

Breaking: existing devices require a factory reflash — OTA from the old
layout cannot re-partition.

## v1.7.0

Added sound utilities to use the mic.

## v1.6.4

Fix eMMC erlinit.config always using SD device paths (mmcblk1 instead of
mmcblk0). Moved erlinit.config out of `rootfs_overlay/` into variant-specific
overlays (`rootfs_overlay_sd/`, `rootfs_overlay_emmc/`) so that
`Nerves.Erlinit.system_config_file/1` no longer overwrites the correct
Buildroot-applied config during `mix firmware`.

## v1.6.3

Rename rootfs overlay directories from kebab-case to snake_case so
`Nerves.Erlinit.system_config_file/1` finds `erlinit.config` and merges
`:nerves, :erlinit` config from consuming projects.

## v1.6.2

Fix for version 1.6.1 (emmc target always selected)

## v1.6.1

Minor fix.

## v1.6.0

Publishing the `emmc` variant as its own target.

## v1.5.2

Fix on CI when uploading eMMC image.

## v1.5.1

Removing `:` from the device ID.

## v1.5.0

Creating eMMC image

## v1.4.0

Bumped version because of the change.

## v1.3.7

Added the libs necessary for using Image lib in the system.

## v1.3.6

Fix when switching between A/B partitions.

## v1.3.5

Added common USB serial device drivers.

## v1.3.4

Added librstp.

## v1.3.3

Re-organizing project files to make more sense and not reference LicheerV.

## v1.3.2

Triggering a re-build.

## v1.3.1

Updated mix dependencies.

## v1.3.0

Bumped ION memory from 20mb to 64mb.

## v1.2.0

Updated `sscma-elixir` to the latest version.

## v1.1.0

Notable changes:

* Better demo (showing squares where people are detected)
* Using the same camera size as the TPU is using
* Added support for USB dual role
* Added driver for CP210X

## v1.0.0

First fully working version with all the bell and whistles working.

Demo included in the `example` folder.

## v0.18.1

Correctly publishing `sscma-elixir` program in the image and added NixOS support.

## v0.18.0

Added `sscma-elixir` program.

## v0.17.1

Updated CI and using docker builder.

## v0.17.0

Finally, a working camera!

Additionally, we have networking over USB.

Still missing / untested:

* Loading models to the TPU.

## v0.16.0

First boot-to-nerves version!

Working:

* Boots up to iex
* Loads & stores data in u-boot
* Has A/B partitions (untested yet)
* Ethernet driver, WiFi driver
* Most features are already working

Non-working / Untested:

* TPU driver
* Camera

## v0.15.0

Added the `example` folder.

## v0.14.0

Updated version so it matches the current version

## v0.0.1

# First release

First release! Still early, and might not work at all.
