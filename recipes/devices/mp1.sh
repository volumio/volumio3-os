#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Khadas VIM3L boards (not to be published because it is OEM configured)
DEVICE_SUPPORT_TYPE="O" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Import the Khadas vims configuration
# shellcheck source=./recipes/devices/families/kvims.sh
source "${SRC}"/recipes/devices/families/kvims.sh

# Base system
DEVICENAME="Volumio MP1"
DEVICE="mp1"
KHADASBOARDNAME="VIM3L"

# Called by the image builder for mp1 (VIM3L) overrides default declaration
device_image_tweaks() {

  #TODO ===> remove when reboot for MP1 resolved

  log "With VIM3 or MP1 (VIM3L): adding temporary fix for reboot fix "
  mv "${ROOTFSMNT}/sbin/ifconfig" "${ROOTFSMNT}/opt"
  mv "${ROOTFSMNT}/bin/ip" "${ROOTFSMNT}/opt"
  cp "${PLTDIR}/${DEVICEBASE}/opt/ifconfig.fix" "${ROOTFSMNT}/sbin/ifconfig"
  cp "${PLTDIR}/${DEVICEBASE}/opt/ip.fix" "${ROOTFSMNT}/bin/ip"

  log "With VIM3 or MP1 (VIM3L): fix issue with AP6359SA and AP6398S using the same chipid and rev"
  cp "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_apsta_ap6398s.bin" "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_apsta.bin"
  cp "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag_ap6398s.bin" "${ROOTFSMNT}/lib/firmware/brcm/fw_bcm4359c0_ag.bin"
  cp "${ROOTFSMNT}/lib/firmware/brcm/nvram_ap6398s.txt" "${ROOTFSMNT}/lib/firmware/brcm/nvram_ap6359sa.txt"
  cp "${ROOTFSMNT}/lib/firmware/brcm/BCM4359C0_ap6398s.hcd" "${ROOTFSMNT}/lib/firmware/brcm/BCM4359C0.hcd"
  
  log "Add missing config file for AP6359SA and AP6398S"
  cp "${ROOTFSMNT}/lib/firmware/brcm/config.txt" "${ROOTFSMNT}/lib/firmware/brcm/config_bcm4359c0_ag.txt"
  sed -i "s/ccode=CN/ccode=ALL/g" "${ROOTFSMNT}/lib/firmware/brcm/config_bcm4359c0_ag.txt"

  log "With VIM2/ VIM3/ MP1(VIM3L): adding fan services"
  cp "${PLTDIR}/${DEVICEBASE}/lib/systemd/system/fan.service" "${ROOTFSMNT}/lib/systemd/system"

  #TODO: remove the mp1 restriction when reboot works
  #do not use the system-halt.service for mp1 yet
  cp "${PLTDIR}/${DEVICEBASE}/etc/rc.local.mp1" "${ROOTFSMNT}/etc/rc.local"

  log "add udev rule for Realtek USB ethernet adapters"
  cat <<-EOF > "${ROOTFSMNT}/etc/udev/rules.d/50-usb-realtek-net.rules"
  # This is used to change the default configuration of Realtek USB ethernet adapters
		ACTION!="add", GOTO="usb_realtek_net_end"
		SUBSYSTEM!="usb", GOTO="usb_realtek_net_end"
		ENV{DEVTYPE}!="usb_device", GOTO="usb_realtek_net_end"
		# Modify this to change the default value
		ENV{REALTEK_MODE1}="1"
		ENV{REALTEK_MODE2}="3"
		# Realtek
		ATTR{idVendor}=="0bda", ATTR{idProduct}=="815[2,3,5,6]", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="0bda", ATTR{idProduct}=="8053", ATTR{bcdDevice}=="e???", ATTR{bConfigurationValue}!="$env{REALTEK_MODE2}", ATTR{bConfigurationValue}="$env{REALTEK_MODE2}"
		# Samsung
		ATTR{idVendor}=="04e8", ATTR{idProduct}=="a101", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		# Lenovo
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="304f", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="3052", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="3054", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="3057", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="3062", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="3069", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="3082", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="3098", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="7205", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="720a", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="720b", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="720c", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="7214", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="721e", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="8153", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="a359", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		ATTR{idVendor}=="17ef", ATTR{idProduct}=="a387", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		# TP-LINK
		ATTR{idVendor}=="2357", ATTR{idProduct}=="0601", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		# Nvidia
		ATTR{idVendor}=="0955", ATTR{idProduct}=="09ff", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		# LINKSYS
		ATTR{idVendor}=="13b1", ATTR{idProduct}=="0041", ATTR{bConfigurationValue}!="$env{REALTEK_MODE1}", ATTR{bConfigurationValue}="$env{REALTEK_MODE1}"
		LABEL="usb_realtek_net_end"
EOF
}
