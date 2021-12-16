#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for NanoPi Neo2 H5 based devices
DEVICE_SUPPORT_TYPE="O" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm64"

### Device information
DEVICENAME="NanoPi M4"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="rk3399"
# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="https://github.com/gkkpch/platform-${DEVICEFAMILY}"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes

## Partition info
BOOT_START=21
BOOT_END=378
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramsfs
MODULES=("overlay" "overlayfs" "squashfs" "nls_cp437" "fuse")
# Packages that will be installed
# PACKAGES=("u-boot-tools")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  log "Copying the platform defaults"
  cp -dR "${PLTDIR}/${DEVICE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/firmware" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/u-boot" "${ROOTFSMNT}"

  log "Creating temp targets for .deb unpacking"
  [ -e "tmp_boot-lib-dtb" ] && rm -r tmp_boot-lib-dtb
  [ -e "tmp_firmware" ] && rm -r tmp_firmware
  [ -e "tmp_u-boot" ] && rm -r tmp_u-boot
  mkdir tmp_boot-lib-dtb
  mkdir tmp_firmware
  mkdir tmp_u-boot
  
  log "Unpacking boot, lib and dtb from Armbian  .deb file..." "info"
  dpkg-deb -R ${PLTDIR}/${DEVICE}/armbian/linux-image*.deb tmp_boot-lib-dtb
  cp -dR tmp_boot-lib-dtb/boot/vmlinuz-* "${ROOTFSMNT}/boot/Image"
  cp -dR tmp_boot-lib-dtb/boot/config* "${ROOTFSMNT}/boot/"
  cp -pdR tmp_boot-lib-dtb/lib/modules "${ROOTFSMNT}/lib"
  cp -pdR tmp_boot-lib-dtb/usr/lib/linux-image*/rockchip "${ROOTFSMNT}/boot/dtb"  

  log "Unpacking firmware from Armbian .deb file..." "info"
  dpkg-deb -R ${PLTDIR}/${DEVICE}/armbian/armbian-firmware*.deb tmp_firmware
  cp -pdR "tmp_firmware/lib/firmware" "${ROOTFSMNT}/lib"  

  log "Unpacking u-boot from Armbian .deb file..." "info"
  dpkg-deb -R ${PLTDIR}/${DEVICE}/armbian/linux-u-boot* tmp_u-boot
  cp tmp_u-boot/usr/lib/linux-u-boot*/* ${PLTDIR}/${DEVICE}/u-boot

#TODO cards.json


}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICE}/u-boot/idbloader.bin" of="${LOOP_DEV}" bs=1024 seek=64
  dd if="${PLTDIR}/${DEVICE}/u-boot/uboot.img" of="${LOOP_DEV}" bs=1024 seek=16384
  dd if="${PLTDIR}/${DEVICE}/u-boot/trust.bin" of="${LOOP_DEV}" bs=1024 seek=24576
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  #log "Performing device_chroot_tweaks_pre" "ext"
  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >/etc/sysctl.conf
abi.cp15_barrier=2
EOF

  log "Creating boot parameters from template"
  sed -i "s/imgpart=UUID=/imgpart=UUID=${UUID_IMG}/g" /boot/varsVolumio.txt
  sed -i "s/bootpart=UUID=/bootpart=UUID=${UUID_BOOT}/g" /boot/varsVolumio.txt
  sed -i "s/datapart=UUID=/datapart=UUID=${UUID_DATA}/g" /boot/varsVolumio.txt

  # log "Adding gpio group and udev rules"
  # groupadd -f --system gpio
  # usermod -aG gpio volumio
  # #TODO: Refactor to cat
  # touch /etc/udev/rules.d/99-gpio.rules
  # echo "SUBSYSTEM==\"gpio\", ACTION==\"add\", RUN=\"/bin/sh -c '
  #         chown -R root:gpio /sys/class/gpio && chmod -R 770 /sys/class/gpio;\
  #         chown -R root:gpio /sys$DEVPATH && chmod -R 770 /sys$DEVPATH    '\"" >/etc/udev/rules.d/99-gpio.rules
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  :
}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
  log "Running device_image_tweaks_post" "ext"
  log "Creating uInitrd from 'volumio.initrd'" "info"
  if [[ -f "${ROOTFSMNT}"/boot/volumio.initrd ]]; then
    mkimage -v -A "${UINITRD_ARCH}" -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d "${ROOTFSMNT}"/boot/volumio.initrd "${ROOTFSMNT}"/boot/uInitrd
    rm "${ROOTFSMNT}"/boot/volumio.initrd
  fi
}
