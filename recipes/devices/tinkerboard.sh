#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Asus Tinerboard device
DEVICE_SUPPORT_TYPE="S" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Debian"
ARCH="armhf"
BUILD="armv7"
UINITRD_ARCH="arm"

PLYMOUTH_THEME="volumio-player"
# Debug image
DEBUG_IMAGE=no

### Device information
DEVICENAME="Asus Tinkerboard"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="tinkerboard"
# tarball from DEVICEFAMILY repo to use
#DEVICEBASE=${DEVICE} # Defaults to ${DEVICE} if unset
DEVICEREPO="https://github.com/volumio/platform-asus.git"

### What features do we want to target
# TODO: Not fully implement
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes
KIOSKMODE=yes
KIOSKBROWSER=vivaldi

## Partition info
BOOT_START=1
BOOT_END=64
BOOT_TYPE=msdos          # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="initv3" 

# Modules that will be added to intramsfs
MODULES=("overlay" "overlayfs" "squashfs" "nls_cp437")
# Packages that will be installed
PACKAGES=("")

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

  cp -dR "${PLTDIR}/${DEVICE}/boot" "${ROOTFSMNT}"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/modules" "${ROOTFSMNT}/lib"
  cp -pdR "${PLTDIR}/${DEVICE}/lib/firmware" "${ROOTFSMNT}/lib"

	log "Copying selected Volumio ${PLYMOUTH_THEME} theme" "info"
	cp -dR "${SRC}/volumio/plymouth/themes/${PLYMOUTH_THEME}" ${ROOTFSMNT}/usr/share/plymouth/themes/${PLYMOUTH_THEME}
}

write_device_bootloader() {
  log "Running write_device_bootloader" "ext"

  dd if="${PLTDIR}/${DEVICE}/u-boot/u-boot.img" of="${LOOP_DEV}" seek=64 conv=notrunc

}

# Will be called by the image builder for any customisation
device_image_tweaks() {
  :
}

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"
  # Grab latest kernel version
  mapfile -t kernel_versions < <(ls -t /lib/modules | sort)
  log "Creating extlinux.conf for Kernel -- ${kernel_versions[0]}"

  log "Preparing boot configurations" "cfg"
  if [[ $DEBUG_IMAGE == yes ]]; then
		log "Debug image: use 'nosplash' in cmdline" "info"
		SHOW_SPLASH="nosplash" # Debug removed
		log "Debug image: cmdline without 'quiet', add 'break=' and 'loglevel'" "info"
		KERNEL_QUIET="loglevel=8 break= use_kmsg=yes" # Default Debug
  else
		log "Default image: use splash in cmdline" "info"
		SHOW_SPLASH="splash plymouth.ignore-serial-consoles initramfs.clear" # Default splash enabled
		log "Default image: use 'quiet' and 'loglevel=0' in cmdline" "info"
		KERNEL_QUIET="quiet loglevel=0" # Default quiet enabled, loglevel default to KERN_EMERG
  fi

  cat <<-EOF >/boot/extlinux/extlinux.conf
	label $(awk -F . '{print "kernel-"$1"."$2}' <<<"${kernel_versions[0]}")
	  kernel /zImage
	  fdt /dtb/rk3288-miniarm.dtb
	  initrd /uInitrd
	  append  earlyprintk ${KERNEL_QUIET} ${SHOW_SPLASH} console=tty1 console=ttyS3,115200n8 rw init=/sbin/init imgpart=UUID=${UUID_IMG} imgfile=/volumio_current.sqsh bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA} uuidconfig=/extlinux/extlinux.conf vt.global_cursor_default=0
	EOF
  
  log "Tinkerboard Init"
  echo "#!/bin/sh
  echo 2 > /proc/irq/45/smp_affinity" > /usr/local/bin/tinker-init.sh
  chmod +x /usr/local/bin/tinker-init.sh

  log "Primo DAC"
  echo "primodac=\`sudo /usr/sbin/i2cdetect -y 1 0x48 0x48 | grep -E 'UU|48' | awk '{print \$2}'\`
  if [ ! -z \"\$primodac\" ]; then
    configured=\`cat /boot/hw_intf.conf | grep es90x8q2m-dac | awk -F '=' '{print \$2}'\`
    if [ -z \"\$configured\" ]; then
      echo \"For information only, you may safely delete this file\" > /boot/dacdetect.log
      echo \"\`date\`: Volumio Primo DAC detected on i2c address 0x48...\" >> /boot/dacdetect.log
      volumioconfigured=\`cat /boot/hw_intf.conf | grep \"#### Volumio i2s \" \`
      if [ ! -z \"\$volumioconfigured\" ]; then
        echo \"\`date\`: Another DAC configured, wiping it out...\" >> /boot/dacdetect.log
        mv /boot/hw_intf.conf /boot/hw_intf.tmp
        sed '/#### Volumio i2s setting below/Q' /boot/hw_intf.tmp >/boot/hw_intf.conf
        rm /boot/hw_intf.tmp
      fi
      echo \"\`date\`: Automatically configuring ES90x8Q2M and reboot...\" >> /boot/dacdetect.log
      echo \"#### Volumio i2s setting below: do not alter ####\" >> /boot/hw_intf.conf
      echo \"intf:dtoverlay=es90x8q2m-dac\" >> /boot/hw_intf.conf
      /sbin/reboot
    fi
  fi" > /usr/local/bin/detect-primo.sh
  chmod +x /usr/local/bin/detect-primo.sh

  echo "#!/bin/sh -e
  /usr/local/bin/tinker-init.sh
  /usr/local/bin/detect-primo.sh
  exit 0" > /etc/rc.local

  chmod +x /usr/local/bin/tinker-init.sh

  log "USB Card Ordering"
  cat <<-EOF >/etc/modprobe.d/alsa-base.conf
  # USB DACs will have device number 5 in whole Volumio device range
  # For tinkerboard, we specify that internal USB audio should be at device 1
  options snd-usb-audio index=1,5 vid=0x0bda pid=0x481a
	EOF

  log "Installing Tinkerboard Bluetooth Utils and Firmware"
  wget http://repo.volumio.org/Volumio2/Firmwares/rtl_bt_tinkerboard.tar.gz
  tar xf rtl_bt_tinkerboard.tar.gz -C /
  rm rtl_bt_tinkerboard.tar.gz
  systemctl enable tinkerbt.service
 
  log "Fix for bluetooth enable"
  echo 'echo "Enabling Bluetooth"
  /bin/hciconfig hci0 up' >> /bin/init_tinkerboard_bt

  log "Installing updated Realtek firmwares"
  wget https://github.com/volumio/volumio3-os-static-assets/raw/master/firmwares/firmware-realtek_20210818-1_all.deb
  dpkg -i firmware-realtek_20210818-1_all.deb
  rm firmware-realtek_20210818-1_all.deb

  # Thsis needs to be MOST for buster
  #log "Changing to 'modules=dep'"
  #sed -i "s/MODULES=most/MODULES=dep/g" /etc/initramfs-tools/initramfs.conf
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
}
