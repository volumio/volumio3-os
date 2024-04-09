#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Radxa Zero 3W
DEVICE_SUPPORT_TYPE="S" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm64"

### Device information
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="rk3566"
# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="https://github.com/gkkpch/platform-${DEVICEFAMILY}.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes

## Partition info
BOOT_START=20
BOOT_END=96
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="initv3" 

# Modules that will be added to intramsfs
MODULES=("overlay" "overlayfs" "squashfs" "nls_cp437"  "fuse")
# Packages that will be installed
PACKAGES=("bluez-firmware" "bluetooth" "bluez" "bluez-tools")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
  log "Running write_device_files" "ext"

  cp -dR "${PLTDIR}/${DEVICE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/firmware" "${ROOTFSMNT}/lib"
}

write_device_bootloader() {
  :
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

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {


# Configure kernel parameters, overrule $verbosity in order to keep the template (platform files) untouched
  if [ "${DEBUG_IMAGE}" == "yes" ]; then
    log "Configuring DEBUG kernel parameters" "cfg"
    sed -i "s/loglevel=\${verbosity}/loglevel=8 nosplash break= use_kmsg=yes/" /boot/boot.cmd
  else
    log "Configuring default kernel parameters" "cfg"
    sed -i "s/loglevel=\${verbosity}/quiet loglevel=0/" /boot/boot.cmd
    if [[ -n "${PLYMOUTH_THEME}" ]]; then
      log "Adding splash kernel parameters" "cfg"      
      sed -i "s/loglevel=0/loglevel=0 splash plymouth.ignore-serial-consoles initramfs.clear/" /boot/boot.cmd
    fi  
  fi

  log "Performing device_chroot_tweaks_pre" "ext"
  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >>/etc/sysctl.conf
abi.cp15_barrier=2
EOF

  log "Adding tty rules"
  cat <<-EOF >/etc/udev/rules.d/52-tty.rules
KERNEL=="tty[0-9]*",MODE="0666"
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
  # log "Running device_chroot_tweaks_post" "ext"
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
  if [[ -f "${ROOTFSMNT}"/boot/boot.cmd ]]; then
    log "Creating boot.scr"
    mkimage -A arm -T script -C none -d "${ROOTFSMNT}"/boot/boot.cmd "${ROOTFSMNT}"/boot/boot.scr
  fi
}
