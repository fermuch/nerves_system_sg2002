## v0.0.1

# First release

First release! Still early, and might not work at all.

## v0.14.0

Updated version so it matches the current version

## v0.15.0

Added the `example` folder.

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

## v0.17.0

Finally, a working camera!

Additionally, we have networking over USB.

Still missing / untested:

* Loading models to the TPU.

## v0.17.1

Updated CI and using docker builder.

## v0.18.0

Added `sscma-elixir` program.

## v0.18.1

Correctly publishing `sscma-elixir` program in the image and added NixOS support.

## v1.0.0

First fully working version with all the bell and whistles working.

Demo included in the `example` folder.

## v1.1.0

Notable changes:

* Better demo (showing squares where people are detected)
* Using the same camera size as the TPU is using
* Added support for USB dual role
* Added driver for CP210X