#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Khadas device.
# Note: these images are using vendor kernel & u-boot, generated with the
#       Khadas Fenix build system

DEVICE_SUPPORT_TYPE="O" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm64"

# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="khadas"
DEVICEBASE="vims-5.15"
# tarball from DEVICEFAMILY repo to use
DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}.git"

UBOOTBIN="u-boot.bin.sd.bin.signed"
### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=yes
VOLINITUPDATER=yes
KIOSKMODE=yes

## Partition info
BOOT_START=16
BOOT_END=256
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
IMAGE_END=3800
INIT_TYPE="initv3"
PLYMOUTH_THEME="volumio-player"

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437" "fuse")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -LR "${PLTDIR}/${DEVICEBASE}/boot" "${ROOTFSMNT}"
  cp -L "${PLTDIR}/${DEVICEBASE}/boot/extlinux/extlinux.conf.${DEVICE}" "${ROOTFSMNT}"/boot/extlinux/extlinux.conf
  cp -L "${PLTDIR}/${DEVICEBASE}/boot/uEnv.txt.${DEVICE}" "${ROOTFSMNT}"/boot/uEnv.txt
  rm "${ROOTFSMNT}"/boot/extlinux/extlinux.conf.vim*
  rm "${ROOTFSMNT}"/boot/uEnv.txt.vim*

  sed -i "s/hwdevice=/hwdevice=${DEVICE}/" "${ROOTFSMNT}"/boot/uEnv.txt

  cp -R "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"

  log "Adding broadcom wlan firmware for vims onboard wlan"
  cp -pR "${PLTDIR}/${DEVICEBASE}/hwpacks/wlan-firmware/brcm/" "${ROOTFSMNT}/lib/firmware"

  log "Adding Meson video firmware"
  cp -pR "${PLTDIR}/${DEVICEBASE}/hwpacks/video-firmware/Amlogic/${DEVICE}"/* "${ROOTFSMNT}/lib/firmware/"

  log "Adding Wifi & Bluetooth firmware and helpers NOT COMPLETED, TBS"
  cp "${PLTDIR}/${DEVICEBASE}/hwpacks/bluez/hciattach-armhf" "${ROOTFSMNT}/usr/local/bin/hciattach"
  cp "${PLTDIR}/${DEVICEBASE}/hwpacks/bluez/brcm_patchram_plus-armhf" "${ROOTFSMNT}/usr/local/bin/brcm_patchram_plus"

  log "Adding services"
  mkdir -p "${ROOTFSMNT}/lib/systemd/system"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/bluetooth-khadas.service" "${ROOTFSMNT}/lib/systemd/system"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/fan.service" "${ROOTFSMNT}/lib/systemd/system"

  log "Load modules, specific for vims, to /etc/modules" 
  cp -R "${PLTDIR}/${DEVICEBASE}/etc" "${ROOTFSMNT}/"
  cp "${PLTDIR}/${DEVICEBASE}/etc/initramfs-tools/modules.${DEVICE}" "${ROOTFSMNT}/etc/initramfs-tools/modules"
  cp "${PLTDIR}/${DEVICEBASE}/etc/modprobe.d.${DEVICE}"/* "${ROOTFSMNT}/etc/modprobe.d/"
  cp "${PLTDIR}/${DEVICEBASE}/etc/modules.${DEVICE}" "${ROOTFSMNT}/etc/modules"

  rm "${ROOTFSMNT}"/etc/initramfs-tools/modules.vim*
  rm -rf "${ROOTFSMNT}"/etc/modprobe.d.vim*
  rm "${ROOTFSMNT}"/etc/modules.vim*

  log "Adding usr/local/bin & usr/bin files"
  cp -R "${PLTDIR}/${DEVICEBASE}/usr" "${ROOTFSMNT}"

  log "Copying volumio configuration"
  cp -R "${PLTDIR}/${DEVICEBASE}/volumio" "${ROOTFSMNT}/"
}

write_device_bootloader() {

  log "Running write_device_bootloader" "ext"
  dd if="${PLTDIR}/${DEVICEBASE}/u-boot/${DEVICE}/${UBOOTBIN}" of="${LOOP_DEV}" bs=444 count=1 conv=fsync,notrunc >/dev/null 2>&1
  dd if="${PLTDIR}/${DEVICEBASE}/u-boot/${DEVICE}/${UBOOTBIN}" of="${LOOP_DEV}" bs=512 skip=1 seek=1 conv=fsync,notrunc >/dev/null 2>&1

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

### Chroot tweaks
# Will be run in chroot (before other things)
device_chroot_tweaks() {
  :
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  # log "Running device_chroot_tweaks_post" "ext"
  :
}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
  # log "Running device_image_tweaks_post" "ext"
  :
}

