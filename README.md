# Nerves System for SG2002-based boards

This is a custom [Nerves](https://nerves-project.org) system for SG2002-based single-board computers powered by the Sophgo SG2002 SoC.

## Project Overview

This Nerves system provides a complete, bootable Linux image tailored for Elixir applications. It's built using [Buildroot](https://buildroot.org) and includes the necessary kernel, bootloader, and root filesystem to run Elixir applications on SG2002-based devices.

The system is based on the official Sophgo SDK and has been adapted to work with the Nerves platform.

## Features

*   **RISC-V 64-bit Architecture**: Targets the `riscv64` architecture with the `lp64d` ABI.
*   **Linux Kernel**: Uses the Sophgo Linux 5.10 kernel.
*   **U-Boot Bootloader**: Utilizes the Sophgo U-Boot 2021.10 bootloader.
*   **Toolchain**: Built with a custom Musl-based toolchain.
*   **Networking**: Supports networking via the onboard WiFi module.
*   **Peripherals**: Includes support for various peripherals like GPIO, I2C, and SPI.

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

*   [Elixir](https://elixir-lang.org/install.html)
*   [Erlang](https://www.erlang.org/downloads)
*   [Nerves Bootstrap](https://hexdocs.pm/nerves_bootstrap/Nerves.Bootstrap.html)

### Building the Firmware

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/fermuch/nerves_system_sg2002.git
    cd nerves_system_sg2002
    ```

2.  **Set up your Elixir project:**
    Create a new Elixir project or use an existing one.

    ```bash
    mix nerves.new my_app
    cd my_app
    ```

3.  **Add the system as a dependency:**
    In your `mix.exs` file, add this system to your dependencies:

    ```elixir
    def deps do
      [
        # ... other dependencies
        {:nerves_system_sg2002, github: "fermuch/nerves_system_sg2002", tag: "v0.1.0"}
      ]
    end
    ```

4.  **Specify the target:**
    In your `mix.exs`, set the target to `nerves_system_sg2002`:

    ```elixir
    def project do
      [
        # ...
        target: "nerves_system_sg2002"
      ]
    end
    ```

5.  **Get dependencies and build the firmware:**
    ```bash
    mix deps.get
    mix firmware
    ```

### Deploying to SG2002-based devices

1.  **Prepare an SD card:**
    Format an SD card with a FAT32 partition.

2.  **Burn the firmware:**
    Use the `fwup` tool to burn the firmware to the SD card.

    ```bash
    mix firmware.burn
    ```

3.  **Boot the device:**
    Insert the SD card into your SG2002-based device and power it on. The device will boot into the Nerves system, and your Elixir application will start automatically.

## Further Information

*   **Nerves Project**: [https://nerves-project.org](https://nerves-project.org)
*   **Buildroot**: [https://buildroot.org](https://buildroot.org)
*   **Sophgo SDK**: [https://github.com/sophgo/](https://github.com/sophgo/)
