# Buildroot Packages

This directory contains custom Buildroot packages for the SG2002 Nerves system.

## Package Status

| Package | Status | Description |
|---------|--------|-------------|
| **aic-firmware** | Enabled | AIC wireless firmware blobs (WiFi) |
| **cloudutils** | Enabled | Cloud image utilities |
| **cvitek-fbtools** | Available | Framebuffer tools for CVITEK boards |
| **cvitek-middleware** | Available | CVITEK middleware and sample applications |
| **cvitek-modules** | Enabled | CVITEK kernel modules for SG2002 |
| **cvitek-oss** | Enabled | CVITEK open source components |
| **cvitek-pinmux** | Enabled | Pin configuration utility |
| **cvitekconfig** | Enabled | Board configuration (memory map, panel selection, heap allocation) |
| **libhv** | Available | HTTP library for C/C++ (dependency of sscma) |
| **miniz** | Enabled | Compression library (zlib replacement) |
| **recamera-sdk** | Available | reCamera SDK for SSCMA components |
| **sg2002-nerves-fixes** | Available | Nerves-specific toolchain fixes |
| **sscma-elixir** | Enabled | Elixir wrapper for SSCMA (TPU/Camera ML) |
| **sscma-node** | Enabled | Node.js-based SSCMA runtime |

## Status Legend

- **Enabled**: Package is built and included in the firmware
- **Available**: Package is defined but not enabled in `nerves_defconfig`

## Enabling a Package

To enable an available package, add the corresponding `BR2_PACKAGE_*=y` option to `nerves_defconfig`. For example:

```
BR2_PACKAGE_CVITEK_FDTOOLS=y
```

## Package Dependencies

Some packages have dependencies that are automatically selected:

- `sscma-node` and `sscma-elixir` depend on `libhv` and `recamera-sdk`
- `cvitekconfig` is required by most CVITEK packages

## Adding New Packages

1. Create a directory: `package/<name>/`
2. Create `<name>.mk` following Buildroot conventions
3. Create `Config.in` for package options
4. The package is auto-included via `external.mk`
