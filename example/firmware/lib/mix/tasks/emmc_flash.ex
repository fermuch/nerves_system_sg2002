defmodule Mix.Tasks.EmmcFlash do
  use Mix.Task

  @shortdoc "Flash eMMC from a device currently booted off SD card"

  @moduledoc """
  Builds eMMC firmware (if needed) and flashes it to /dev/mmcblk0 on the
  target device via SSH.

  The device must be booted from SD so that the eMMC is not in use.

  ## Usage

      NERVES_STORAGE=emmc MIX_TARGET=nerves_system_sg2002 mix emmc.flash
      NERVES_STORAGE=emmc MIX_TARGET=nerves_system_sg2002 mix emmc.flash --target 192.168.1.100

  ## Options

    * `--target` - device hostname or IP (default: `nerves.local`)
    * `--port`   - SSH port (default: `22`)
    * `--user`   - SSH user (default: `root`)
    * `--fw`     - path to .fw file (default: auto-detected from build dir)

  """

  @default_target "nerves.local"
  @default_port 22
  @default_user "root"
  @emmc_device "/dev/mmcblk0"
  @remote_fw "/data/emmc_flash.fw"

  def run(argv) do
    {opts, _, _} =
      OptionParser.parse(argv,
        switches: [target: :string, port: :integer, user: :string, fw: :string]
      )

    target = opts[:target] || @default_target
    port = opts[:port] || @default_port
    user = opts[:user] || @default_user

    fw_path =
      opts[:fw] ||
        Path.join([
          Mix.Project.build_path(),
          "nerves",
          "images",
          "#{Mix.Project.config()[:app]}.fw"
        ])

    unless File.exists?(fw_path) do
      Mix.raise(
        "Firmware file not found: #{fw_path}\n" <>
          "Build it first with: NERVES_STORAGE=emmc MIX_TARGET=nerves_system_sg2002 mix firmware"
      )
    end

    remote_fw = @remote_fw

    Mix.shell().info("Firmware: #{fw_path}")
    Mix.shell().info("Target:   #{user}@#{target}:#{port}")
    Mix.shell().info("")

    Mix.shell().info("==> Uploading firmware to #{target}...")
    scp!(fw_path, remote_fw, user, target, port)

    Mix.shell().info("==> Flashing eMMC (#{@emmc_device}) — this may take a minute...")

    ssh!(
      "fwup -a -d #{@emmc_device} -t complete -i #{remote_fw} && rm -f #{remote_fw}",
      user,
      target,
      port
    )

    Mix.shell().info("")

    Mix.shell().info(
      "eMMC flashed successfully. Power cycle the board (remove SD card) to boot from eMMC."
    )
  end

  defp scp!(local, remote, user, host, port) do
    args = [
      "-P",
      to_string(port),
      "-o",
      "StrictHostKeyChecking=no",
      "-o",
      "UserKnownHostsFile=/dev/null",
      local,
      "#{user}@#{host}:#{remote}"
    ]

    run_cmd!("scp", args)
  end

  defp ssh!(cmd, user, host, port) do
    args = [
      "-p",
      to_string(port),
      "-o",
      "StrictHostKeyChecking=no",
      "-o",
      "UserKnownHostsFile=/dev/null",
      "-t",
      "#{user}@#{host}",
      cmd
    ]

    run_cmd!("ssh", args)
  end

  defp run_cmd!(bin, args) do
    case System.cmd(bin, args, into: IO.stream(:stdio, :line), stderr_to_stdout: true) do
      {_, 0} -> :ok
      {_, code} -> Mix.raise("#{bin} exited with code #{code}")
    end
  end
end
