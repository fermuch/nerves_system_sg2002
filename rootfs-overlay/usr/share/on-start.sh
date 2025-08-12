#!/bin/sh

# # Initialize mdev for hotplug/coldplug and load core Wi-Fi modules
# echo /sbin/mdev > /proc/sys/kernel/hotplug
# /sbin/mdev -s

# Set up Sensor (camera)
GPIO_SENSOR_PWR=358
if [ ! -d /sys/class/gpio/gpio$GPIO_SENSOR_PWR ]; then
  echo $GPIO_SENSOR_PWR > /sys/class/gpio/export
  echo "out" > /sys/class/gpio/gpio$GPIO_SENSOR_PWR/direction
fi
if [ -f /sys/class/gpio/gpio$GPIO_SENSOR_PWR/value ]; then
  echo 1 > /sys/class/gpio/gpio$GPIO_SENSOR_PWR/value
fi

# Install base kernel modules
insmod /usr/share/modules/cv181x_sys.ko
insmod /usr/share/modules/cv181x_base.ko
insmod /usr/share/modules/cv181x_rtos_cmdqu.ko
insmod /usr/share/modules/cv181x_fast_image.ko
insmod /usr/share/modules/cvi_mipi_rx.ko
insmod /usr/share/modules/snsr_i2c.ko
insmod /usr/share/modules/cv181x_vi.ko vi_log_lv=1
insmod /usr/share/modules/cv181x_vpss.ko vpss_log_lv=1
insmod /usr/share/modules/cv181x_dwa.ko
insmod /usr/share/modules/cv181x_vo.ko vo_log_lv=1
insmod /usr/share/modules/cv181x_mipi_tx.ko
insmod /usr/share/modules/cv181x_rgn.ko
insmod /usr/share/modules/cv181x_clock_cooling.ko
insmod /usr/share/modules/cv181x_tpu.ko
insmod /usr/share/modules/cv181x_vcodec.ko
insmod /usr/share/modules/cv181x_jpeg.ko
insmod /usr/share/modules/cvi_vc_driver.ko MaxVencChnNum=9 MaxVdecChnNum=9
insmod /usr/share/modules/cv181x_ive.ko
insmod /usr/share/modules/cfg80211.ko
insmod /usr/share/modules/brcmutil.ko
insmod /usr/share/modules/brcmfmac.ko

# Check if nerves_serial_number exists, if not create it
if ! fw_printenv nerves_serial_number > /dev/null 2>&1; then
  ID=$(uuidgen -r | sed 's/-//g')
  fw_setenv nerves_serial_number "$ID"
  echo "Setting nerves_serial_number to: $ID"
fi