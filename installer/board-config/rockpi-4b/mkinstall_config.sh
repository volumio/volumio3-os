#!/bin/bash

# Device Info RockPi 4B
DEVICEBASE="rock4"
BOARDFAMILY="rockpi-4b"
PLATFORMREPO="https://github.com/gkkpch/platform-${DEVICEBASE}.git"
BUILD="armv7"
NONSTANDARD_REPO=no	# yes requires "non_standard_repo() function in make.sh 
LBLBOOT="BOOT"
LBLIMAGE="volumio"
LBLDATA="volumio_data"

# Partition Info
BOOT_TYPE=msdos			# msdos or gpt   
BOOT_START=20
BOOT_END=148
IMAGE_END=3800
BOOT=/mnt/boot
BOOTDELAY=1
BOOTDEV="mmcblk0"
BOOTPART=/dev/${BOOTDEV}p1
BOOTCONFIG=armbianEnv.txt

TARGETBOOT="/dev/mmcblk1p1"
TARGETDEV="/dev/mmcblk1"
TARGETDATA="/dev/mmcblk1p3"
TARGETIMAGE="/dev/mmcblk1p2"
HWDEVICE="rockpi-4b"
USEKMSG="yes"
UUIDFMT="yes"			# yes|no (actually, anything non-blank)
FACTORYCOPY="yes"


# Modules to load (as a blank separated string array)
MODULES="nls_cp437 fuse"

# Additional packages to install (as a blank separated string)
#PACKAGES=""

# initramfs type
RAMDISK_TYPE=image		# image or gzip (ramdisk image = uInitrd, gzip compressed = volumio.initrd) 

non_standard_repo()
{
   :
}

fetch_bootpart_uuid()
{
   :
}

is_dataquality_ok()
{
   return 0
}

write_device_files()
{
  cp ${PLTDIR}/${BOARDFAMILY}/boot/Image ${ROOTFSMNT}/boot
  cp ${PLTDIR}/${BOARDFAMILY}/boot/armbianEnv.txt ${ROOTFSMNT}/boot
  cp ${PLTDIR}/${BOARDFAMILY}/boot/boot.scr ${ROOTFSMNT}/boot
  cp -dR ${PLTDIR}/${BOARDFAMILY}/boot/dtb ${ROOTFSMNT}/boot
} 

write_device_bootloader()
{
  dd if=${PLTDIR}/${BOARDFAMILY}/u-boot/idbloader.img of=${LOOP_DEV} seek=64 conv=notrunc status=none
  dd if=${PLTDIR}/${BOARDFAMILY}/u-boot/u-boot.itb of=${LOOP_DEV} seek=16384 conv=notrunc status=none
}

copy_device_bootloader_files()
{
   mkdir ${ROOTFSMNT}/boot/u-boot
   cp ${PLTDIR}/${BOARDFAMILY}/u-boot/idbloader.img $ROOTFSMNT/boot/u-boot
   cp ${PLTDIR}/${BOARDFAMILY}/u-boot/u-boot.itb $ROOTFSMNT/boot/u-boot
}

write_boot_parameters()
{
   sed -i "s/verbosity/#verbosity/g" $ROOTFSMNT/boot/armbianEnv.txt
   sed -i "s/imgpart=UUID= bootpart=UUID= datapart=UUID= bootconfig=armbianEnv.txt imgfile=\/volumio_current.sqsh net.ifnames=0/loglevel=0/g" $ROOTFSMNT/boot/armbianEnv.txt
   sed -i "s/user_overlays=spdif_sound//g" $ROOTFSMNT/boot/armbianEnv.txt
}




