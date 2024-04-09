#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Radxa Zero family of devices (Amlogic S905Y2/ A311D)
DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm64"

# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="radxazero"
# tarball from DEVICEFAMILY repo to use
DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes
KIOSKMODE=no

## Partition info
BOOT_START=20
BOOT_END=84
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
  cp -pdR "${PLTDIR}/${DEVICE}/var/" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICE}/volumio" "${ROOTFSMNT}"
  
  log "Mark the boot partition with radxa-zero version "${VERSION}""
  log "${VERSION}" > "${ROOTFSMNT}"/boot/radxa-zero.version
  
}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"
    
  dd if="${PLTDIR}/${DEVICE}/u-boot/u-boot.bin" of="${LOOP_DEV}" bs=1 count=442 conv=fsync
  dd if="${PLTDIR}/${DEVICE}/u-boot/u-boot.bin" of="${LOOP_DEV}" bs=512 skip=1 seek=1 conv=fsync

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
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Creating boot parameters from template"
  sed -i "s/imgpart=UUID=/imgpart=UUID=${UUID_IMG}/g" /boot/armbianEnv.txt
  sed -i "s/bootpart=UUID=/bootpart=UUID=${UUID_BOOT}/g" /boot/armbianEnv.txt
  sed -i "s/datapart=UUID=/datapart=UUID=${UUID_DATA}/g" /boot/armbianEnv.txt

# Configure kernel parameters, overrule $verbosity in order to keep the template (platform files) untouched
# Deactivate Armbian bootlogo settings
  sed -i "s/splash=verbose//" /boot/boot.cmd 
  sed -i "s/splash plymouth.ignore-serial-consoles//" /boot/boot.cmd

  if [ "${DEBUG_IMAGE}" == "yes" ]; then
    log "Configuring DEBUG kernel parameters" "cfg"
    sed -i "s/loglevel=\${verbosity}/loglevel=8 nosplash break= use_kmsg=yes/" /boot/boot.cmd
  else
    log "Configuring default kernel parameters" "cfg"
    sed -i "s/console=both/console=serial/" /boot/armbianEnv.txt
    sed -i "s/loglevel=\${verbosity}/quiet loglevel=0/" /boot/boot.cmd
    if [[ -n "${PLYMOUTH_THEME}" ]]; then
      log "Adding splash kernel parameters" "cfg"      
      sed -i "s/loglevel=0/loglevel=0 splash plymouth.ignore-serial-consoles initramfs.clear/" /boot/boot.cmd
    fi  
  fi

  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >/etc/sysctl.conf
abi.cp15_barrier=2
EOF

  log "Changing initramfs module config to 'modules=list' to limit volumio.initrd size" "cfg"
  sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf
	
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
  if [[ -f "${ROOTFSMNT}/boot/volumio.initrd" ]]; then
    mv "${ROOTFSMNT}/boot/volumio.initrd" ${SRC}
    mkimage -v -A "${UINITRD_ARCH}" -O linux -T ramdisk -C none -a 0 -e 0 -n uInitrd -d "${SRC}/volumio.initrd" "${ROOTFSMNT}/boot/uInitrd"
    rm "${SRC}/volumio.initrd"
  fi
  if [[ -f "${ROOTFSMNT}"/boot/boot.cmd ]]; then
    log "Creating boot.scr"
    mkimage -A arm -T script -C none -d "${ROOTFSMNT}"/boot/boot.cmd "${ROOTFSMNT}"/boot/boot.scr
  fi
}
