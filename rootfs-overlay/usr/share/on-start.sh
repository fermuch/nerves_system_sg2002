#!/bin/sh

# # Initialize mdev for hotplug/coldplug and load core Wi-Fi modules
# echo /sbin/mdev > /proc/sys/kernel/hotplug
# /sbin/mdev -s

# Set up I2C2 pins for camera
# devmem 0x0300119c 32 0x00000004   # set GPIO_C14 to I²C2_SDA
# devmem 0x030011a0 32 0x00000004   # set GPIO_C15 to I²C2_SCL

# # Load CVI camera/video kernel modules
# /sbin/modprobe cv181x_sys 2>/dev/null || true
# /sbin/modprobe cv181x_base 2>/dev/null || true
# /sbin/modprobe snsr_i2c 2>/dev/null || true
# /sbin/modprobe cvi_mipi_rx 2>/dev/null || true
# /sbin/modprobe cv181x_vi 2>/dev/null || true
# /sbin/modprobe cv181x_vpss 2>/dev/null || true
# /sbin/modprobe cv181x_cif 2>/dev/null || true
# /sbin/modprobe cvi_vc_driver 2>/dev/null || true

# Set up Sensor (camera)
GPIO_SENSOR_PWR=358
if [ ! -d /sys/class/gpio/gpio$GPIO_SENSOR_PWR ]; then
  echo $GPIO_SENSOR_PWR > /sys/class/gpio/export
  echo "out" > /sys/class/gpio/gpio$GPIO_SENSOR_PWR/direction
fi
if [ -f /sys/class/gpio/gpio$GPIO_SENSOR_PWR/value ]; then
  echo 1 > /sys/class/gpio/gpio$GPIO_SENSOR_PWR/value
fi

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

# Install base kernel modules
# insmod /usr/share/modules/cv181x_sys.ko
# insmod /usr/share/modules/cv181x_base.ko
# insmod /usr/share/modules/cv181x_rtos_cmdqu.ko
# insmod /usr/share/modules/cv181x_fast_image.ko
# insmod /usr/share/modules/cvi_mipi_rx.ko
# insmod /usr/share/modules/snsr_i2c.ko
# insmod /usr/share/modules/cv181x_vi.ko vi_log_lv=1
# insmod /usr/share/modules/cv181x_vpss.ko vpss_log_lv=1
# insmod /usr/share/modules/cv181x_dwa.ko
# insmod /usr/share/modules/cv181x_vo.ko vo_log_lv=1
# insmod /usr/share/modules/cv181x_mipi_tx.ko
# insmod /usr/share/modules/cv181x_rgn.ko
# insmod /usr/share/modules/cv181x_clock_cooling.ko
# insmod /usr/share/modules/cv181x_tpu.ko
# insmod /usr/share/modules/cv181x_vcodec.ko
# insmod /usr/share/modules/cv181x_jpeg.ko
# insmod /usr/share/modules/cvi_vc_driver.ko MaxVencChnNum=9 MaxVdecChnNum=9
# insmod /usr/share/modules/cv181x_ive.ko
# insmod /usr/share/modules/brcmutil.ko

# # Try to load Wi-Fi stack
modprobe cfg80211 2>/dev/null || true
modprobe mac80211 2>/dev/null || true
modprobe brcmfmac 2>/dev/null || true

# Check if nerves_serial_number exists, if not create it
if ! fw_printenv nerves_serial_number > /dev/null 2>&1; then
  ID=$(uuidgen -r | sed 's/-//g')
  fw_setenv nerves_serial_number "$ID"
  echo "Setting nerves_serial_number to: $ID"
fi