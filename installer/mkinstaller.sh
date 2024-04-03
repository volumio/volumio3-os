#!/bin/bash
#set -x
SRC="$(pwd)"
FAILED=0

. ${SRC}/scripts/helpers.sh

if [ "$EUID" -ne 0 ]
  then log "Please run as root" "err"
  exit
fi

if [ ! "$#" == "2" ]; then
   log "Incorrect number of parameters supplied, aborting" "err"
   log "Usage: sudo ./mkinstaller -i <image>" "info"
   exit
fi

while getopts ":i:" opt; do
  case $opt in

    i)
      if [ ! -e $OPTARG ]; then
         log "Volumio image $OPTARG does not exist, aborting..." "err"
         exit 1
      fi
      
      VOLUMIOIMAGE=$OPTARG
      # split the image name in elements and parse
      IMAGEPATH=$(echo $VOLUMIOIMAGE | awk 'BEGIN{FS=OFS="/"}NF--')
      IMAGENAME=$(echo $VOLUMIOIMAGE | awk -F "/" '{print $NF}')

      # get variant from image file name
      VARIANT=$(echo $(echo $IMAGENAME | awk -F "-" '{print $1}') | awk -F "/" '{print $NF}')

      # get version and build date from image name
      BUILDVER=$(echo $IMAGENAME | awk -F "-" '{print $2}')
      BUILDDATE=$(echo $IMAGENAME | awk -F "-" '{print $3"-"$4"-"$5}')

      # get player extension
      ext=$(echo $(echo $IMAGENAME | awk -F "-" '{print $7}') | awk -F "." '{print $1}')
      PLAYER=$(echo $(echo $IMAGENAME | awk -F "-" '{print $6}') | awk -F "." '{print $1}')
      if [ ! "${ext}*" == "*" ]; then
        PLAYER="${PLAYER}-${ext}"
      fi
      ;;
    *)
      echo "Invalid parameter, aborted"
      exit
      ;;
  esac
done

. ${SRC}/installer/board-config/${PLAYER}/mkinstall_config.sh

log "+------EXTRA STEP: Building Auto Installer "
log "       Variant:    $VARIANT"
log "       Version:    $BUILDVER"
log "       Build date: $BUILDDATE"
log "       Player:     $PLAYER"
log ""

if [ -z ${VOLUMIOIMAGE} ]; then
   log "No Volumio image supplied, aborting..." "err"
   exit 1
fi



PLTDIR="${SRC}/platform-${DEVICEBASE}"
rootfs_tarball="${SRC}/build/${BUILD}"_rootfs
if [ -f "${rootfs_tarball}.lz4" ]; then
   log "Trying to use prior base system" "info"
   if [ -d ${SRC}/build/${BUILD} ]; then
     log "Prior ${BUILD} rootfs dir found!" "dbg"  "$(date -r "${SRC}/build/${BUILD}" "+%m-%d-%Y %H:%M:%S")"
     [ ${CLEAN_ROOTFS:-yes} = yes ] &&
       log "Cleaning prior rootfs directory" "wrn" && rm -rf "${SRC}/build/${BUILD}"
   fi
   log "Using prior Base tarball" "$(date -r "${rootfs_tarball}.lz4" "+%m-%d-%Y %H:%M:%S")"
   mkdir -p ./build/${BUILD}/root
   pv -p -b -r -c -N "[ .... ] $rootfs_tarball" "${rootfs_tarball}.lz4" |
     lz4 -dc |
     tar xp --xattrs -C ./build/${BUILD}/root
   if [ ! -d "${PLTDIR}" ]; then
      log "No platform folder ${PLTDIR} present, please build a volumio device image first" "err"
	  exit 1
   fi
else
   log "No ${rootfs_tarball} present, please build a volumio device image first" "err"
   exit 1
fi

IMG_FILE=$SRC/"Autoinstaller-$VARIANT-${BUILDVER}-${BUILDDATE}-${PLAYER}.img"
VOLMNT=/mnt/volumio

log "[Stage 1] Creating AutoFlash Image File ${IMG_FILE}"

dd if=/dev/zero of=${IMG_FILE} bs=1M count=1000

log "[Stage 1] Creating Image Bed" "info"
LOOP_DEV=$(losetup -f --show "${IMG_FILE}")
# Note: leave the first 20Mb free for the firmware
parted -s "${LOOP_DEV}" mklabel ${BOOT_TYPE}
parted -s "${LOOP_DEV}" mkpart primary fat16 21 100%
parted -s "${LOOP_DEV}" set 1 boot on
partprobe "${LOOP_DEV}"
kpartx -s -a "${LOOP_DEV}"

FLASH_PART=`echo /dev/mapper/"$( echo ${LOOP_DEV} | sed -e 's/.*\/\(\w*\)/\1/' )"p1`
if [ ! -b "${FLASH_PART}" ]
then
   log "[Stage 1] ${FLASH_PART} doesn't exist, aborting..." "err"
   exit 1
fi

log "[Stage 1] Creating boot and rootfs filesystem" "info"
mkfs -t vfat -n BOOT "${FLASH_PART}"
fetch_bootpart_uuid

log "[Stage 1] Preparing for the  kernel/ platform files" "info"
if [ ! -z $NONSTANDARD_REPO ]; then
   non_standard_repo
else
   HAS_PLTDIR=no
   if [ -d ${PLTDIR} ]; then
      pushd ${PLTDIR}
      # it should not happen that the 
      if [ -d ${BOARDFAMILY} ]; then
         HAS_PLTDIR=yes
      fi
      popd
   fi
   if [ $HAS_PLTDIR == no ]; then
      # This should normally not happen, just handle it for safety
      if [ -d ${PLTDIR} ]; then
         rm -r ${PLTDIR}  
	  fi
      log "[Stage 1]  Clone platform files from repo" "info"
      git clone $PLATFORMREPO
      log "[Stage 1] Unpacking the platform files" "info"
      pushd $PLTDIR
      tar xfJ ${BOARDFAMILY}.tar.xz
      rm ${BOARDFAMILY}.tar.xz
      popd
   fi
fi

log "[Stage 1] Writing the bootloader" "info"
write_device_bootloader

sync

log "[Stage 1] Preparing for Volumio rootfs" "info"
if [ -d /mnt ]
then
	log "[Stage 1] /mount folder exist" "info"
else
	mkdir /mnt
fi
if [ -d $VOLMNT ]
then
	log "[Stage 1] Volumio Temp Directory Exists - Cleaning it" "wrn"
	rm -rf $VOLMNT/*
else
	log "[Stage 1] Creating Volumio Temp Directory" "info"
	mkdir $VOLMNT
fi

log "[Stage 1] Creating mount points" "info"
ROOTFSMNT=$VOLMNT/rootfs
mkdir $ROOTFSMNT
mkdir $ROOTFSMNT/boot
mount -t vfat "${FLASH_PART}" $ROOTFSMNT/boot

log "[Stage 1] Copying RootFs" "info"
cp -pdR ${SRC}/build/$BUILD/root/* $ROOTFSMNT
mkdir $ROOTFSMNT/root/scripts

log "[Stage 1] Copying initrd config" "info"
echo "BOOT_TYPE=${BOOT_TYPE}   
BOOT_START=${BOOT_START}
BOOT_END=${BOOT_END}
IMAGE_END=${IMAGE_END}
BOOT=${BOOT}
BOOTDELAY=${BOOTDELAY}
BOOTDEV=${BOOTDEV}
BOOTPART=${BOOTPART}
BOOTCONFIG=${BOOTCONFIG}
TARGETBOOT=${TARGETBOOT}
TARGETDEV=${TARGETDEV}
TARGETDATA=${TARGETDATA}
TARGETIMAGE=${TARGETIMAGE}
HWDEVICE=${HWDEVICE}
USEKMSG=${USEKMSG}
UUIDFMT=${UUIDFMT}
LBLBOOT=${LBLBOOT}
LBLIMAGE=${LBLIMAGE}
LBLDATA=${LBLDATA}
FACTORYCOPY=${FACTORYCOPY}
" > $ROOTFSMNT/root/scripts/initconfig.sh

log "[Stage 1] Copying initrd scripts" "info"
cp ${SRC}/installer/board-config/${PLAYER}/board-functions $ROOTFSMNT/root/scripts
cp ${SRC}/installer/runtime-generic/gen-functions $ROOTFSMNT/root/scripts
cp ${SRC}/installer/runtime-generic/init-script $ROOTFSMNT/root/init
cp ${SRC}/installer/mkinitrd.sh $ROOTFSMNT

log "[Stage 1] Copying kernel modules" "info"
cp -pdR ${PLTDIR}/$BOARDFAMILY/lib/modules $ROOTFSMNT/lib/

log "[Stage 1] writing board-specific files" "info"
write_device_files

log "[Stage 1] Writing board-specific boot parameters" "info"
write_boot_parameters

sync

log "[Stage 2] Run chroot to create an initramfs" "info"
cp scripts/initramfs/mkinitramfs-custom.sh $ROOTFSMNT/usr/local/sbin

echo "
RAMDISK_TYPE=${RAMDISK_TYPE}
MODULES=\"${MODULES}\"
PACKAGES=\"${PACKAGES}\"
" > $ROOTFSMNT/config.sh

mount /dev $ROOTFSMNT/dev -o bind
mount /proc $ROOTFSMNT/proc -t proc
mount /sys $ROOTFSMNT/sys -t sysfs

chroot $ROOTFSMNT /bin/bash -x <<'EOF'
su -
/mkinitrd.sh
EOF

if [ ${RAMDISK_TYPE} = image ]; then
   log "[Stage 3] Creating uInitrd from 'volumio.initrd'"
   mkimage -A arm -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d $ROOTFSMNT/boot/volumio.initrd $ROOTFSMNT/boot/uInitrd
   rm $ROOTFSMNT/boot/volumio.initrd
fi

#cleanup
rm -r $ROOTFSMNT/mkinitrd.sh $ROOTFSMNT/config.sh  $ROOTFSMNT/root/init $ROOTFSMNT/root/scripts

log "[Stage 4] Creating Volumio boot & image data folder" 
mkdir -p $ROOTFSMNT/boot/data/boot
mkdir -p $ROOTFSMNT/boot/data/image

if [ -d /mnt/volumioimage ]
then
	log "[Stage 4] Volumio Image mountpoint exists - Cleaning it" "wrn"
	rm -rf /mnt/volumioimage/*
else
	log "[Stage 4] Creating Volumio Image mountpoint" "info"
	mkdir /mnt/volumioimage
fi

log "[Stage 4]  Create loopdevice for mounting volumio image" "info"
LOOP_DEV1=$(losetup -f)
losetup -P ${LOOP_DEV1} ${VOLUMIOIMAGE}
BOOT_PART=${LOOP_DEV1}p1
IMAGE_PART=${LOOP_DEV1}p2

log "[Stage 4]  Mount volumio image partitions" "info"
mkdir -p /mnt/volumioimage/boot
mkdir -p /mnt/volumioimage/image
mount -t vfat "${BOOT_PART}" /mnt/volumioimage/boot
mount -t ext4 "${IMAGE_PART}" /mnt/volumioimage/image

log "[Stage 5] Do quality check prior to copying files"
is_dataquality_ok
if [ $? -ne 0 ]; then
	log "[Stage 5] Quality check failed, aborting..." "err"
    FAILED=1
else
	log "[Stage 5] Copy bootloader files" "info"
	copy_device_bootloader_files

	log "[Stage 5] Copying 'raw' boot & image data" "info"
	#cd /mnt/volumioimage/boot
	tar cf $ROOTFSMNT/boot/data/image/kernel_current.tar -C /mnt/volumioimage/boot .
	cp /mnt/volumioimage/image/* /mnt/volumio/rootfs/boot/data/image
fi

umount -l /mnt/volumioimage/boot
umount -l /mnt/volumioimage/image
rm -r /mnt/volumioimage

log "[Stage 6] Unmounting Temp devices"
umount -l $ROOTFSMNT/dev
umount -l $ROOTFSMNT/proc
umount -l $ROOTFSMNT/sys
umount -l $ROOTFSMNT/boot

log "[Stage 4] Removing Rootfs" "info"
rm -r $ROOTFSMNT/*

sync

dmsetup remove_all
losetup -d ${LOOP_DEV1}
losetup -d ${LOOP_DEV}

if [ $FAILED -eq 0 ]; then
	zip -j ${IMG_FILE}.zip ${IMG_FILE}
else
	rm ${IMG_FILE}
fi

log "Installer ready" "okay"
sync
