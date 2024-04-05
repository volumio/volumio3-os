#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid M1S
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# shellcheck source=./recipes/devices/families/rk3566.sh
source "${SRC}"/recipes/devices/families/rk3566.sh

### Device information
DEVICENAME="Odroid M1S"

KIOSKMODE=no
KIOSKBROWSER=vivaldi

# Plymouth theme?
PLYMOUTH_THEME="volumio-player"
# Debug image?
DEBUG_IMAGE="no"

## Partition info
BOOT_END=84

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
  dd if="${PLTDIR}/${DEVICE}/u-boot/idblock.bin" of="${LOOP_DEV}" conv=fsync seek=64
  dd if="${PLTDIR}/${DEVICE}/u-boot/uboot.img" of="${LOOP_DEV}" conv=fsync seek=2048
}

### Chroot tweaks
# Will be run in chroot (before other things)
device_chroot_tweaks() {
  log "Creating boot parameters from template"
  sed -i "s/bootconfig/uuidconfig/" /boot/bootparams.ini
  sed -i "s/imgpart=UUID=/imgpart=UUID=${UUID_IMG}/g" /boot/bootparams.ini
  sed -i "s/bootpart=UUID=/bootpart=UUID=${UUID_BOOT}/g" /boot/bootparams.ini
  sed -i "s/datapart=UUID=/datapart=UUID=${UUID_DATA}/g" /boot/bootparams.ini

}

