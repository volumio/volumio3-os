#!/usr/bin/env bash
# shellcheck disable=SC2034

### Device information
DEVICENAME="Khadas VIM4"
DEVICE="vim4"

KIOSKBROWSER=vivaldi

# Packages that will be installed
PACKAGES=("fbset" )

# Import the Khadas vims configuration
# shellcheck source=./recipes/devices/families/vims-5.15.sh
source "${SRC}"/recipes/devices/families/vims-5.15.sh

# Will be run in chroot - Pre initramfs
device_chroot_tweaks_pre() {
  log "Performing device_chroot_tweaks_pre" "ext"

  sed -i "s/#imgpart=UUID=/imgpart=UUID=${UUID_IMG}/g" /boot/uEnv.txt
  sed -i "s/#bootpart=UUID=/bootpart=UUID=${UUID_BOOT}/g" /boot/uEnv.txt
  sed -i "s/#datapart=UUID=/datapart=UUID=${UUID_DATA}/g" /boot/uEnv.txt

#  cat <<-EOF >>/boot/dtb/amlogic/kvim4.dtb.overlay.env
#fdt_overlays=i2s spdifout uart_c renamesound
#EOF
  
  # Do not use i2s for the time being (needs to be checked)
  cat <<-EOF >>/boot/dtb/amlogic/kvim4.dtb.overlay.env
fdt_overlays=spdifout uart_e renamesound panfrost
EOF
  cp /boot/dtb/amlogic/kvim4.dtb.overlay.env /boot/dtb/amlogic/kvim4n.dtb.overlay.env

  log "Fixing armv8 deprecated instruction emulation, allow dmesg"
  cat <<-EOF >>/etc/sysctl.conf
#Fixing armv8 deprecated instruction emulation with armv7 rootfs
abi.cp15_barrier=2
#Allow dmesg for non.sudo users
kernel.dmesg_restrict=0
EOF

# Bluez looks for firmware in /etc/firmware/, enable bluetooth stack
  ln -sf /lib/firmware /etc/firmware
  ln -s /lib/systemd/system/bluetooth-khadas.service /etc/systemd/system/multi-user.target.wants/bluetooth-khadas.service

# Patches used by hciattach
  ln -fs /lib/firmware/brcm/BCM43438A1.hcd /lib/firmware/brcm/BCM43430A1.hcd # AP6212
  ln -fs /lib/firmware/brcm/BCM4356A2.hcd /lib/firmware/brcm/BCM4354A2.hcd # AP6356S

  ln -s /lib/systemd/system/fan.service /etc/systemd/system/multi-user.target.wants/fan.service

  if [ "${DEBUG_IMAGE}" == "yes" ]; then
    log "Configuring DEBUG image" "info"
    sed -i "s/quiet loglevel=0 splash/loglevel=8 nosplash break= use_kmsg=yes/" /boot/uEnv.txt
  else
    log "Configuring default kernel parameters" "info"
    if [[ -n "${PLYMOUTH_THEME}" ]]; then
      log "Adding splash kernel parameters" "info"
      sed -i "s/loglevel=0 splash/loglevel=0 splash plymouth.ignore-serial-consoles initramfs.clear/" /boot/uEnv.txt
    else
      log "No splash screen, just quiet" "info"
      sed -i "s/loglevel=0 splash/loglevel=0 nosplash/" /boot/uEnv.txt
    fi
  fi
}
