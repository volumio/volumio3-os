#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Odroid C4 device  (Community Portings)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm64"

### Device information
DEVICEFAMILY="odroid"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEREPO="https://github.com/volumio/platform-odroid.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=yes
VOLINITUPDATER=yes
KIOSKMODE=no

## Partition info
BOOT_START=1
BOOT_END=64
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="initv3"

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("lirc" "fbset")

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {

  if [ ! -z ${PLYMOUTH_THEME} ]; then
    log "Plymouth selected, adding plymouth-label to list of packages to install" ""
    PACKAGES+=("plymouth-label")
  	log "Copying selected Volumio ${PLYMOUTH_THEME} theme" "cfg"
    cp -dR "${SRC}/volumio/plymouth/themes/${PLYMOUTH_THEME}" ${ROOTFSMNT}/usr/share/plymouth/themes/${PLYMOUTH_THEME}
  fi

  log "Running write_device_files" "ext"

  cp ${PLTDIR}/${DEVICEBASE}/boot/*.ini "${ROOTFSMNT}/boot"
  cp -dR "${PLTDIR}/${DEVICEBASE}/boot/amlogic" "${ROOTFSMNT}/boot"
  cp "${PLTDIR}/${DEVICEBASE}/boot/Image.gz" "${ROOTFSMNT}/boot"
  cp ${PLTDIR}/${DEVICEBASE}/boot/config-* "${ROOTFSMNT}/boot"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICEBASE}/lib/firmware" "${ROOTFSMNT}/lib"

  log "Add additional firmware (mainly wifi)"
  cp -dR "${PLTDIR}/${DEVICEBASE}/firmware" "${ROOTFSMNT}/lib"

  log "Copying rc.local for ${DEVICENAME} performance tweaks"
  cp "${PLTDIR}/${DEVICEBASE}/etc/rc.local" "${ROOTFSMNT}/etc"

  log "Copying LIRC configuration files for HK stock remote"
  cp "${PLTDIR}/${DEVICEBASE}/etc/lirc/lircd.conf" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICEBASE}/etc/lirc/hardware.conf" "${ROOTFSMNT}"
  cp "${PLTDIR}/${DEVICEBASE}/etc/lirc/lircrc" "${ROOTFSMNT}"

}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICEBASE}/uboot/u-boot.bin" of="${LOOP_DEV}" conv=fsync,notrunc bs=512 seek=1
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  log "Creating UUIDs in boot.ini" "cfg"
  sed -i "s/bootconfig/uuidconfig/" /boot/boot.ini
  sed -i "s/%%VOLUMIO-PARAMS%%/imgpart=UUID=${UUID_IMG} bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA}/" /boot/boot.ini

  # Configure kernel parameters, overrule $verbosity in order to keep the template (platform files) untouched
  if [ "${DEBUG_IMAGE}" == "yes" ]; then
    log "Configuring DEBUG kernel parameters" "cfg"
    sed -i "s/loglevel=\$verbosity/loglevel=8 nosplash break= use_kmsg=yes/" /boot/boot.ini
  else
    log "Configuring default kernel parameters" "cfg"
    sed -i "s/loglevel=\$verbosity/quiet loglevel=0/" /boot/boot.ini
    if [ ! -z "${PLYMOUTH_THEME}" ]; then
      log "Adding splash kernel parameters" "cfg"
      plymouth-set-default-theme -R ${PLYMOUTH_THEME}
      sed -i "s/loglevel=0/loglevel=0 splash plymouth.ignore-serial-consoles initramfs.clear/" /boot/boot.ini
    fi  
  fi

  log "Fixing armv8 deprecated instruction emulation with armv7 rootfs"
  cat <<-EOF >>/etc/sysctl.conf
abi.cp15_barrier=2
EOF
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  log "Configuring HK stock remote"
  cp lircd.conf /etc/lirc
  cp hardware.conf /etc/lirc
  cp lircrc /etc/lirc
  rm lircd.conf hardware.conf lircrc

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
