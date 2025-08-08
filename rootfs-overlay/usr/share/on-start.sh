#!/bin/sh

# Initialize mdev for hotplug/coldplug and load core Wi-Fi modules
echo /sbin/mdev > /proc/sys/kernel/hotplug
/sbin/mdev -s

# Try to load Wi-Fi stack (ignore errors if already built-in)
/sbin/modprobe cfg80211 2>/dev/null || true
/sbin/modprobe mac80211 2>/dev/null || true
/sbin/modprobe brcmfmac 2>/dev/null || true

# Check if nerves_serial_number exists, if not create it
if ! fw_printenv nerves_serial_number > /dev/null 2>&1; then
  ID=$(uuidgen -r | sed 's/-//g')
  fw_setenv nerves_serial_number "$ID"
  echo "Setting nerves_serial_number to: $ID"
fi