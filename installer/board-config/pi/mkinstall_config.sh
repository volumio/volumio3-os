#!/bin/bash

# Device Info Raspberry Pi
DEVICEBASE="pi"
BOARDFAMILY="raspberry"
DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}.git"
BUILD="armv"
NONSTANDARD_REPO=no	# yes requires "non_standard_repo() function in make.sh
LBLBOOT="BOOT"
LBLIMAGE="volumio"
LBLDATA="volumio_data"

# Partition Info
BOOT_TYPE=msdos			# msdos or gpt
BOOT_START=0
BOOT_END=96
IMAGE_END=2800
BOOT=/mnt/boot
BOOTDELAY=1
BOOTDEV="mmcblk1"
BOOTPART=/dev/mmcblk1p1
BOOTCONFIG=cmdline.txt

TARGETBOOT="/dev/mmcblk0p1"
TARGETDEV="/dev/mmcblk0"
TARGETDATA="/dev/mmcblk0p3"
TARGETIMAGE="/dev/mmcblk0p2"
HWDEVICE="yes"
USEKMSG="yes"
UUIDFMT="yes"			# yes|no (actually, anything non-blank)
FACTORYCOPY="yes"

# Modules to load (as a blank separated string array)
MODULES=(
	# Direct Rendering Manager with Plymouth
	"drm" "drm_dma_helper" "drm_display_helper" "drm_kms_helper" "drm_panel_orientation_quirks" "drm_rp1_dsi" "drm_shmem_helper"
	# Video DRM core
	"v3d" "vc4"
	# Video buffer
	"videobuf2_v4l2" "videobuf2_common" "videobuf2_dma_contig" "v4l2_mem2mem" "videobuf2_memops"
	# GPU scheduler
	"gpu_sched"
	# Platform encoders
	"rpivid_hevc" "videodev"
	# Backllight
	"backlight" "gpio_backlight" "lm3630a_bl" "pwm_bl" "rpi_backlight"
	# Bridge
	"display_connector" "simple_bridge" "tc358762"
	# Platform
	"rpisense_fb" "ssd1307fb" "tc358762"
	# DRM panels
	"panel_ilitek_ili9806e" "panel_ilitek_ili9881c" "panel_jdi_lt070me05000" "panel_simple" "panel_sitronix_st7701" "panel_tdo_y17p" "panel_raspberrypi_touchscreen" "panel_waveshare_dsi"
	# DRM tiny panels
	"panel_mipi_dbi" "hx8357d" "ili9225" "ili9341" "ili9486" "repaper" "st7586" "st7735r"
	# Power regulators
	"rpi_panel_attiny_regulator" "rpi_panel_v2_regulator"
	# i2c
	"i2c_designware_core" "i2c_designware_platform" "i2c_dev" "i2c_gpio" "regmap_i2c" "ssd1307fb"
	# USB
	"udl"
	# System
	"fuse" "nls_cp437" "nls_iso8859_1" "nvme" "nvme_core" "overlay" "squashfs" "uas"
	# Problematic clocks
	"clk_hifiberry_dacpro" "clk_hifiberry_dachd"
	# Problematic DACs
	"snd_soc_hifiberry_adc" "snd_soc_hifiberry_dacplus" "snd_soc_hifiberry_dacplushd" "snd_soc_hifiberry_dacplusadc" "snd_soc_hifiberry_dacplusadcpro" "snd_soc_hifiberry_dacplusdsp"
	"snd_soc_rpi_simple_soundcard" "snd_soc_rpi_wm8804_soundcard")

# Additional packages to install (as a blank separated string)
#PACKAGES=""

# initramfs type
RAMDISK_TYPE=gzip		# image or gzip (ramdisk image = uInitrd, gzip compressed = volumio.initrd)

non_standard_repo()
{
   :
}

fetch_bootpart_uuid()
{
echo "[info] replace BOOTPART device by ${FLASH_PART} UUID value"
UUIDBOOT=$(blkid -s UUID -o value ${FLASH_PART})
BOOTPART="UUID=${UUIDBOOT}"
}

is_dataquality_ok()
{
   return 0
}

write_device_files()
{
   :
}

write_device_bootloader()
{
   :
}

copy_device_bootloader_files()
{
   :
}

write_boot_parameters()
{
   sed -i "s/verbosity/#verbosity/g" $ROOTFSMNT/boot/cmdlinux.txt
   sed -i "s/imgpart=UUID= bootpart=UUID= datapart=UUID= bootconfig=cmdlinux.txt imgfile=\/volumio_current.sqsh net.ifnames=0/loglevel=0/g" $ROOTFSMNT/boot/cmdlinux.txt
}




