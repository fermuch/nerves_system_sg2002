#!/bin/sh

# Set up compressed swap (zram) to absorb memory spikes (best-effort, never fails boot)
setup_zram() {
  [ -e /sys/block/zram0/disksize ] || return 0
  grep -q zram0 /proc/swaps 2>/dev/null && return 0
  grep -qw lz4 /sys/block/zram0/comp_algorithm 2>/dev/null && echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null
  mem_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)
  [ -n "$mem_kb" ] && echo $((mem_kb * 3 / 4 * 1024)) > /sys/block/zram0/disksize 2>/dev/null
  mkswap /dev/zram0 >/dev/null 2>&1 && swapon -p 100 /dev/zram0 2>/dev/null
  return 0
}
setup_zram

# Bias the OOM killer away from the BEAM (erlinit forks the VM next; it inherits PID 1's adj)
echo -500 > /proc/1/oom_score_adj 2>/dev/null || true

# Set up Sensor (camera)
GPIO_SENSOR_PWR=358
if [ ! -d /sys/class/gpio/gpio$GPIO_SENSOR_PWR ]; then
  echo $GPIO_SENSOR_PWR > /sys/class/gpio/export
  echo "out" > /sys/class/gpio/gpio$GPIO_SENSOR_PWR/direction
fi
if [ -f /sys/class/gpio/gpio$GPIO_SENSOR_PWR/value ]; then
  echo 1 > /sys/class/gpio/gpio$GPIO_SENSOR_PWR/value
fi

# Load CVI camera/video kernel modules and utilities
modprobe cv181x_rtos_cmdqu
modprobe cv181x_fast_image
modprobe cvi_mipi_rx
modprobe snsr_i2c
modprobe cv181x_vi vi_log_lv=1
modprobe cv181x_vpss vpss_log_lv=1
modprobe cv181x_dwa
modprobe cv181x_vo vo_log_lv=1
modprobe cv181x_mipi_tx
modprobe cv181x_rgn
modprobe cv181x_clock_cooling
modprobe cv181x_tpu
modprobe cv181x_vcodec
modprobe cv181x_jpeg
modprobe cvi_vc_driver MaxVencChnNum=9 MaxVdecChnNum=9
modprobe cv181x_ive

# Try to load Wi-Fi stack
modprobe cfg80211
modprobe mac80211
modprobe brcmfmac

# Set up USB networking
/usr/share/uhubon.sh device >> /tmp/ncm.log 2>&1
/usr/share/run_usb.sh probe ncm >> /tmp/ncm.log 2>&1
/usr/share/run_usb.sh start ncm >> /tmp/ncm.log 2>&1

# Wait until wlan0 is up, up to 60 seconds
for i in {1..60}; do
  if ifconfig wlan0 > /dev/null 2>&1; then
    break
  fi
  sleep 1
done

# If wlan0 is not up after 60 seconds, print an error message
if ! ifconfig wlan0 > /dev/null 2>&1; then
  echo "wlan0 is not up after 60 seconds"
else
  echo "wlan0 is up"
  # Set nerves' serial number to the MAC address of wlan0
  ID=$(ifconfig wlan0 | grep 'HWaddr' | awk '{print $5}' | tr -d ':')
  fw_setenv nerves_serial_number "$ID"
  echo "Setting nerves_serial_number to: $ID"
fi
