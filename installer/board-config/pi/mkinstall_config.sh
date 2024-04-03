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
BOOT_START=20
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
MODULES="nls_cp437 fuse nvme nvme_core usbcore usb_common uas drm"

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




