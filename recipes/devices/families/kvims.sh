#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Khadas devices

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm"

### Build image with initramfs debug info?
DEBUG_IMAGE="no"

### Device information
# This is useful for multiple devices sharing the same/similar kernel
#DEVICENAME="not set here"
DEVICEFAMILY="khadas"
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEBASE="vims"
DEVICEREPO="https://github.com/volumio/platform-khadas.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes
KIOSKMODE=yes
KIOSKBROWSER=vivaldi

## Partition info
BOOT_START=16
BOOT_END=80
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
IMAGE_END=3800
INIT_TYPE="initv3"
PLYMOUTH_THEME="volumio-player"

# Modules that will be added to intramsfs
MODULES=("overlay" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("lirc" "fbset" "mc" "abootimg" "bluez-firmware"
  "bluetooth" "bluez" "bluez-tools" "linux-base" "triggerhappy"
)

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {

  log "Running write_device_files" "ext"

 if [ ! -z ${PLYMOUTH_THEME} ]; then
    log "Plymouth selected, adding plymouth-themes to list of packages to install" ""
    PACKAGES+=("plymouth-label")
  	log "Copying selected Volumio ${PLYMOUTH_THEME} theme" "cfg"
    cp -dR "${SRC}/volumio/plymouth/themes/${PLYMOUTH_THEME}" ${ROOTFSMNT}/usr/share/plymouth/themes/${PLYMOUTH_THEME}
  fi

  cp -R "${PLTDIR}/${DEVICEBASE}/boot" "${ROOTFSMNT}"

  log "AML autoscripts not for Volumio"
  rm "${ROOTFSMNT}/boot/aml_autoscript"
  rm "${ROOTFSMNT}/boot/aml_autoscript.cmd"

  log "Retain copies of u-boot files for Volumio Installer"
  cp -r "${PLTDIR}/${DEVICEBASE}/uboot" "${ROOTFSMNT}/boot"
  cp -r "${PLTDIR}/${DEVICEBASE}/uboot-mainline" "${ROOTFSMNT}/boot"

  log "Copying modules & firmware"
  cp -pR "${PLTDIR}/${DEVICEBASE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pR "${PLTDIR}/${DEVICEBASE}/lib/firmware" "${ROOTFSMNT}/lib"

  log "Adding broadcom wlan firmware for vims onboard wlan"
  cp -pR "${PLTDIR}/${DEVICEBASE}/hwpacks/wlan-firmware/brcm/" "${ROOTFSMNT}/lib/firmware"

  log "Adding Meson video firmware"
  cp -pR "${PLTDIR}/${DEVICEBASE}/hwpacks/video-firmware/Amlogic/video" "${ROOTFSMNT}/lib/firmware/"
  cp -pR "${PLTDIR}/${DEVICEBASE}/hwpacks/video-firmware/Amlogic/meson" "${ROOTFSMNT}/lib/firmware/"

  log "Adding Wifi & Bluetooth firmware and helpers"
  cp "${PLTDIR}/${DEVICEBASE}/hwpacks/bluez/hciattach-armhf" "${ROOTFSMNT}/usr/local/bin/hciattach"
  cp "${PLTDIR}/${DEVICEBASE}/hwpacks/bluez/brcm_patchram_plus-armhf" "${ROOTFSMNT}/usr/local/bin/brcm_patchram_plus"

  log "Adding services"
  mkdir -p "${ROOTFSMNT}/lib/systemd/system"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/bluetooth-khadas.service" "${ROOTFSMNT}/lib/systemd/system"
  if [[ "${DEVICE}" != kvim1 ]]; then
    cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/fan.service" "${ROOTFSMNT}/lib/systemd/system"
  fi

  log "Adding usr/local/bin & usr/bin files"
  cp -pR "${PLTDIR}/${DEVICEBASE}/usr" "${ROOTFSMNT}"

  log "Copying rc.local with all prepared ${DEVICE} tweaks"
  cp "${PLTDIR}/${DEVICEBASE}/etc/rc.local" "${ROOTFSMNT}/etc"

  log "Copying triggerhappy configuration"
  cp -pR "${PLTDIR}/${DEVICEBASE}/etc/triggerhappy" "${ROOTFSMNT}/etc"

	log "Copying selected Volumio ${PLYMOUTH_THEME} theme" "info"
	cp -dR "${SRC}/volumio/plymouth/themes/${PLYMOUTH_THEME}" ${ROOTFSMNT}/usr/share/plymouth/themes/${PLYMOUTH_THEME}

}

write_device_bootloader() {

  log "Running write_device_bootloader u-boot.${KHADASBOARDNAME}.sd.bin" "ext"

  dd if="${PLTDIR}/${DEVICEBASE}/uboot/u-boot.${KHADASBOARDNAME}.sd.bin" of="${LOOP_DEV}" bs=444 count=1 conv=fsync >/dev/null 2>&1
  dd if="${PLTDIR}/${DEVICEBASE}/uboot/u-boot.${KHADASBOARDNAME}.sd.bin" of="${LOOP_DEV}" bs=512 skip=1 seek=1 conv=fsync >/dev/null 2>&1

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "cfg"

  log "Configuring UUID boot parameters" "info"
  
  sed -i "s/#imgpart=UUID=/imgpart=UUID=${UUID_IMG}/g" /boot/env.system.txt
  sed -i "s/#bootpart=UUID=/bootpart=UUID=${UUID_BOOT}/g" /boot/env.system.txt
  sed -i "s/#datapart=UUID=/datapart=UUID=${UUID_DATA}/g" /boot/env.system.txt

  log "Remove default plymouth.ignore-serial-consoles " "info"
  sed -i "s/plymouth.ignore-serial-consoles//" /boot/boot.ini

  log "Replace 'bootconfig' by 'uuidconfig'" "info"
  sed -i "s/bootconfig/uuidconfig/" /boot/boot.ini

  
  if [ "${DEBUG_IMAGE}" == "yes" ]; then
    log "Configuring DEBUG image" "info"
    sed -i "s/quiet loglevel=0 splash/loglevel=8 nosplash break= use_kmsg=yes/" /boot/env.system.txt
  else
    log "Configuring default kernel parameters" "info"
    if [ ! -z "${PLYMOUTH_THEME}" ]; then
      log "Adding splash kernel parameters" "info"
      plymouth-set-default-theme -R ${PLYMOUTH_THEME}
      sed -i "s/loglevel=0/loglevel=0 splash plymouth.ignore-serial-consoles initramfs.clear/" /boot/env.system.txt
    else
      log "No splash screen, just quiet" "info"
      sed -i "s/loglevel=0 splash/loglevel=0 nosplash/" /boot/env.system.txt
    fi  
  fi  

  log "Fixing armv8 deprecated instruction emulation, allow dmesg"
  cat <<-EOF >>/etc/sysctl.conf
#Fixing armv8 deprecated instruction emulation with armv7 rootfs
abi.cp15_barrier=2
#Allow dmesg for non.sudo users
kernel.dmesg_restrict=0
EOF

  log "Adding default wifi"
  echo "dhd" >>"/etc/modules"

  

  log "Disabling login prompt"
  systemctl disable getty@tty1.service
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
  log "Running device_chroot_tweaks_post" "ext"

  log "Configure triggerhappy"
  echo "DAEMON_OPTS=\"--user root\"" >>"/etc/default/triggerhappy"

  log "Enabling KVIM Bluetooth stack"
  ln -sf "/lib/firmware" "/etc/firmware"
  ln -s "/lib/systemd/system/bluetooth-khadas.service" "/etc/systemd/system/multi-user.target.wants/bluetooth-khadas.service"

  if [[ "${DEVICE}" != kvim1 ]]; then
    ln -s "/lib/systemd/system/fan.service" "/etc/systemd/system/multi-user.target.wants/fan.service"
  fi

  log "Tweaking default WiFi firmware global configuration"
  echo 'kso_enable=0
ccode=ALL
regrev=38
PM=0
nv_by_chip=5 \
43430 0 nvram_ap6212.txt \
43430 1 nvram_ap6212a.txt \
17221 6 nvram_ap6255.txt  \
17236 2 nvram_ap6356.txt \
17241 9 nvram_ap6359sa.txt' > "${ROOTFSMNT}/lib/firmware/brcm/config.txt"
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
}
