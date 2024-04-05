#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for NanoPi M4 based devices
DEVICE_SUPPORT_TYPE="O" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm64"

# Plymouth theme?
PLYMOUTH_THEME="volumio-player"
# Debug image?
DEBUG_IMAGE=no

### Device information
DEVICENAME="NanoPi M4B"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="rk3399"
# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}"

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
INIT_TYPE="initv3" 

# Modules that will be added to intramsfs
MODULES=("overlay" "overlayfs" "squashfs" "nls_cp437" "fuse")
# Packages that will be installed
PACKAGES=("bluez-firmware" "bluetooth" "bluez" "bluez-tools")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  if [ ! -z ${PLYMOUTH_THEME} ]; then
    log "Plymouth selected, adding plymouth-themes to list of packages to install" ""
    PACKAGES+=("plymouth-themes")
  	log "Copying selected Volumio ${PLYMOUTH_THEME} theme" "cfg"
    cp -dR "${SRC}/volumio/plymouth/themes/${PLYMOUTH_THEME}" ${ROOTFSMNT}/usr/share/plymouth/themes/${PLYMOUTH_THEME}
  fi

  log "Copying the platform defaults"
  cp -dR "${PLTDIR}/${DEVICE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/firmware" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/systemd" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/u-boot" "${ROOTFSMNT}"

  log "Mark the boot partition with nanopim4 '${VERSION}'"
  log "${VERSION}" > "${ROOTFSMNT}"/boot/nanopim4.version
  
}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICE}/u-boot/idbloader.bin" of="${LOOP_DEV}" seek=64 conv=notrunc
  dd if="${PLTDIR}/${DEVICE}/u-boot/uboot.img" of="${LOOP_DEV}" seek=16384 conv=notrunc
  dd if="${PLTDIR}/${DEVICE}/u-boot/trust.bin" of="${LOOP_DEV}" seek=24576 conv=notrunc

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {


  log "Creating boot parameters from template"
  sed -i "s/bootconfig/uuidconfig/" /boot/armbianEnv.txt
  sed -i "s/imgpart=UUID=/imgpart=UUID=${UUID_IMG}/g" /boot/armbianEnv.txt
  sed -i "s/bootpart=UUID=/bootpart=UUID=${UUID_BOOT}/g" /boot/armbianEnv.txt
  sed -i "s/datapart=UUID=/datapart=UUID=${UUID_DATA}/g" /boot/armbianEnv.txt

# Configure kernel parameters, overrule $verbosity in order to keep the template (platform files) untouched
  if [ "${DEBUG_IMAGE}" == "yes" ]; then
    log "Configuring DEBUG kernel parameters" "cfg"
    sed -i "s/loglevel=\$verbosity/loglevel=8 nosplash break= use_kmsg=yes/" /boot/boot.cmd
  else
    log "Configuring default kernel parameters" "cfg"
    sed -i "s/loglevel=\$verbosity/quiet loglevel=0/" /boot/boot.cmd
    if [ ! -z "${PLYMOUTH_THEME}" ]; then
      log "Adding splash kernel parameters" "cfg"
      plymouth-set-default-theme -R ${PLYMOUTH_THEME}
      sed -i "s/loglevel=0/loglevel=0 splash plymouth.ignore-serial-consoles initramfs.clear/" /boot/boot.cmd
    fi  
  fi

  #log "Performing device_chroot_tweaks_pre" "ext"
  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >>/etc/sysctl.conf
abi.cp15_barrier=2
EOF

  log "Adding gpio group and udev rules"
  groupadd -f --system gpio
  usermod -aG gpio volumio
  # Works with newer kernels as well
  cat <<-EOF >/etc/udev/rules.d/99-gpio.rules
	SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'find -L /sys/class/gpio/ -maxdepth 2 -exec chown root:gpio {} \; -exec chmod 770 {} \; || true'"
	EOF
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
  log "Creating boot.scr from boot.cmd" "info"
  if [[ -f "${ROOTFSMNT}"/boot/boot.cmd ]]; then
    log "Creating boot.scr"
    mkimage -A arm -T script -C none -d "${ROOTFSMNT}"/boot/boot.cmd "${ROOTFSMNT}"/boot/boot.scr
  fi

}
