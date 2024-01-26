#!/bin/bash

# Device Info Odroid M1S
DEVICEBASE="odroidm1s"
BOARDFAMILY="odroidm1s"
PLATFORMREPO="https://github.com/gkkpch/platform-${DEVICEBASE}.git"
BUILD="armv7"
NONSTANDARD_REPO=no	# yes requires "non_standard_repo() function in make.sh 
LBLBOOT="BOOT"
LBLIMAGE="volumio"
LBLDATA="volumio_data"

# Partition Info
BOOT_TYPE=msdos			# msdos or gpt   
BOOT_START=20
BOOT_END=84
IMAGE_END=3800
BOOT=/mnt/boot
BOOTDELAY=1
BOOTDEV="mmcblk1"
BOOTPART=/dev/mmcblk1p1
BOOTCONFIG=bootparams.ini

TARGETBOOT="/dev/mmcblk0p1"
TARGETDEV="/dev/mmcblk0"
TARGETDATA="/dev/mmcblk0p3"
TARGETIMAGE="/dev/mmcblk0p2"
HWDEVICE="odroidm1s"
USEKMSG="yes"
UUIDFMT="yes"			# yes|no (actually, anything non-blank)
FACTORYCOPY="yes"


# Modules to load (as a blank separated string array)
MODULES="nls_cp437"

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
   cp ${PLTDIR}/${BOARDFAMILY}/boot/Image $ROOTFSMNT/boot
   cp ${PLTDIR}/${BOARDFAMILY}/boot/boot.scr $ROOTFSMNT/boot
   cp ${PLTDIR}/${BOARDFAMILY}/boot/config.ini $ROOTFSMNT/boot
   cp ${PLTDIR}/${BOARDFAMILY}/boot/bootparams.ini $ROOTFSMNT/boot
   
   mkdir $ROOTFSMNT/boot/rockchip
   cp -R ${PLTDIR}/${BOARDFAMILY}/boot/rockchip/* $ROOTFSMNT/boot/rockchip
}

write_device_bootloader()
{
   dd if=${PLTDIR}/${BOARDFAMILY}/u-boot/idblock.bin of=${LOOP_DEV} conv=fsync seek=64
   dd if=${PLTDIR}/${BOARDFAMILY}/u-boot/uboot.img of=${LOOP_DEV} conv=fsync seek=2048
}

copy_device_bootloader_files()
{
   mkdir $ROOTFSMNT/boot/u-boot
   cp ${PLTDIR}/${BOARDFAMILY}/u-boot/idblock.bin $ROOTFSMNT/boot/u-boot
   cp ${PLTDIR}/${BOARDFAMILY}/u-boot/uboot.img $ROOTFSMNT/boot/u-boot
}

write_boot_parameters()
{
   sed -i "s/verbosity/#verbosity/g" $ROOTFSMNT/boot/bootparams.ini
   sed -i "s/imgpart=UUID= bootpart=UUID= datapart=UUID= bootconfig=bootparams.ini imgfile=\/volumio_current.sqsh net.ifnames=0/loglevel=0/g" $ROOTFSMNT/boot/bootparams.ini
   
}




