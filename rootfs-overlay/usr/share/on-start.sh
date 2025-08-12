#!/bin/sh

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

# # Try to load Wi-Fi stack
modprobe cfg80211
modprobe mac80211
modprobe brcmfmac

# Check if nerves_serial_number exists, if not create it
if ! fw_printenv nerves_serial_number > /dev/null 2>&1; then
  ID=$(uuidgen -r | sed 's/-//g')
  fw_setenv nerves_serial_number "$ID"
  echo "Setting nerves_serial_number to: $ID"
fi