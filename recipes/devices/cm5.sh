#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Raspberry Pi
DEVICE_SUPPORT_TYPE="O" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Raspbian"
ARCH="armhf"
BUILD="arm"

### Build image with initramfs debug info?
DEBUG_IMAGE="no" # yes/no or empty. Also changes SHOW_SPLASH in cmdline.txt

### Device information
# Used to identify devices (VOLUMIO_HARDWARE) and keep backward compatibility
#VOL_DEVICE_ID="pi"
DEVICENAME="CM5"
# This is useful for multiple devices sharing the same/similar kernel
#DEVICEFAMILY="raspberry"

# Install to disk tools including PiInstaller
#DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}.git"

### What features do we want to target
# TODO: Not fully implemented
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes
KIOSKMODE=yes
KIOSKBROWSER=vivaldi

## Partition info
BOOT_START=1
BOOT_END=385
IMAGE_END=4673     # BOOT_END + 4288 MiB (/img squashfs)
BOOT_TYPE=msdos    # msdos or gpt
BOOT_USE_UUID=yes  # Add UUID to fstab
INIT_TYPE="initv3"
INIT_UUID_TYPE="pi"    # Use block device GPEN or PARTUUID fallback
## Plymouth theme management
PLYMOUTH_THEME="volumio-player"	# Choices are: {volumio,volumio-logo,volumio-player}
INIT_PLYMOUTH_DISABLE="no"		# yes/no or empty. Removes plymouth initialization in init if "yes" is selected

## TODO: for any KMS DRM panel mudule, which does not create frambuffer bridge, set this variable to yes, otherwise no
## Implement an if/else statement to handle this properly
UPDATE_PLYMOUTH_SERVICES_FOR_KMS_DRM="no"	# yes/no or empty. Replaces default plymouth systemd services if "yes" is selected

# Modules that will be added to initramfs
MODULES=("drm" "fuse" "nls_cp437" "nls_iso8859_1" "nvme" "nvme_core" "overlay" "squashfs" "uas")
# Packages that will be installed
PACKAGES=( # Bluetooth packages
	"bluez-firmware" "pi-bluetooth"
	# Foundation stuff
	"raspberrypi-sys-mods"
	# Framebuffer stuff
	"fbset"	
	# "rpi-eeprom"\ Needs raspberrypi-bootloader that we hold back
	# GPIO stuff
	"wiringpi"
	# Wireless firmware
	"firmware-atheros" "firmware-ralink" "firmware-realtek" "firmware-brcm80211"
)

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
	:
}

write_device_bootloader() {
	#TODO: Look into moving bootloader stuff here
	:
}

# Will be called by the image builder for any customisation
device_image_tweaks() {
	# log "Custom dtoverlay pre and post" "ext"
	# mkdir -p "${ROOTFSMNT}/opt/vc/bin/"
	# cp -rp "${SRC}"/volumio/opt/vc/bin/* "${ROOTFSMNT}/opt/vc/bin/"

	log "Fixing hostapd.conf" "info"
	cat <<-EOF >"${ROOTFSMNT}/etc/hostapd/hostapd.conf"
		interface=wlan0
		driver=nl80211
		channel=4
		hw_mode=g
		wmm_enabled=0
		macaddr_acl=0
		ignore_broadcast_ssid=0
		# Auth
		auth_algs=1
		wpa=2
		wpa_key_mgmt=WPA-PSK
		rsn_pairwise=CCMP
		# Volumio specific
		ssid=Volumio
		wpa_passphrase=volumio2
	EOF

	log "Adding archive.raspberrypi debian repo" "info"
	cat <<-EOF >"${ROOTFSMNT}/etc/apt/sources.list.d/raspi.list"
		deb http://archive.raspberrypi.org/debian/ buster main ui
		# Uncomment line below then 'apt-get update' to enable 'apt-get source'
		#deb-src http://archive.raspberrypi.org/debian/ buster main ui
	EOF

	# raspberrypi-{kernel,bootloader} packages update kernel & firmware files
	# and break Volumio. Installation may be triggered by manual or
	# plugin installs explicitly or through dependencies like
	# chromium, sense-hat, picamera,...
	# Using Pin-Priority < 0 prevents installation
	log "Blocking raspberrypi-bootloader and raspberrypi-kernel" "info"
	cat <<-EOF >"${ROOTFSMNT}/etc/apt/preferences.d/raspberrypi-kernel"
		Package: raspberrypi-bootloader
		Pin: release *
		Pin-Priority: -1

		Package: raspberrypi-kernel
		Pin: release *
		Pin-Priority: -1

		Package: libraspberrypi0
		Pin: release *
		Pin-Priority: -1
	EOF

	RpiUpdateRepo="raspberrypi/rpi-update"
	RpiUpdateBranch="master"
	# RpiUpdateBranch="1dd909e2c8c2bae7adb3eff3aed73c3a6062e8c8"

	log "Fetching rpi-update from repo ${RpiUpdateRepo} and branch ${RpiUpdateBranch}" "info"
	curl -L --output "${ROOTFSMNT}/usr/bin/rpi-update" "https://raw.githubusercontent.com/${RpiUpdateRepo}/${RpiUpdateBranch}/rpi-update" &&
		chmod +x "${ROOTFSMNT}/usr/bin/rpi-update"
	#TODO: Look into moving kernel stuff outside chroot using ROOT/BOOT_PATH to speed things up
	# ROOT_PATH=${ROOTFSMNT}
	# BOOT_PATH=${ROOT_PATH}/boot

	log "Copying custom initramfs script functions" "cfg"
	[ -d ${ROOTFSMNT}/root/scripts ] || mkdir ${ROOTFSMNT}/root/scripts
	cp "${SRC}/scripts/initramfs/custom/pi/custom-functions" ${ROOTFSMNT}/root/scripts
}

# Will be run in chroot (before other things)
device_chroot_tweaks() {
	log "Running device_image_tweaks" "ext"
	# rpi-update needs binutils
	log "Installing binutils for rpi-update" "ext"
	apt-get update -qq && apt-get -yy install binutils
}

# Will be run in chroot - Pre initramfs
# TODO Try and streamline this!
device_chroot_tweaks_pre() {
	log "Changing initramfs module config to 'modules=list' to limit volumio.initrd size" "cfg"
	sed -i "s/MODULES=most/MODULES=list/g" /etc/initramfs-tools/initramfs.conf

	## Define parameters
	declare -A PI_KERNELS=(
		#[KERNEL_VERSION]="SHA|Branch|Rev"
		[6.6.30]="3b768c3f4d2b9a275fafdb53978f126d7ad72a1a|master|1763"
		[6.6.47]="a0d314ac077cda7cbacee1850e84a57af9919f94|master|1792"
		[6.6.51]="d5a7dbe77b71974b9abb133a4b5210a8070c9284|master|1796"
		[6.6.56]="a5efb544aeb14338b481c3bdc27f709e8ee3cf8c|master|1803"
		[6.6.62]="9a9bda382acec723c901e5ae7c7f415d9afbf635|master|1816"
	)
	# Version we want
	KERNEL_VERSION="6.6.62"

	MAJOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d '.' -f 1)
	MINOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d '.' -f 2)
	PATCH_VERSION=$(echo "$KERNEL_VERSION" | cut -d '.' -f 3)

	# List of custom firmware -
	# github archives that can be extracted directly
	declare -A CustomFirmware=(
		[brcmfmac43430b0]="https://raw.githubusercontent.com/volumio/volumio3-os-static-assets/master/firmwares/brcmfmac43430b0/brcmfmac43430b0.tar.gz"
		[PiCustom]="https://raw.githubusercontent.com/Darmur/volumio-rpi-custom/main/output/modules-rpi-${KERNEL_VERSION}-custom.tar.gz"
		[RPiUserlandTools]="https://github.com/volumio/volumio3-os-static-assets/raw/master/tools/rpi-softfp-vc.tar.gz"
	)

	### Kernel installation
	IFS=\. read -ra KERNEL_SEMVER <<<"${KERNEL_VERSION}"
	IFS=\| read -r KERNEL_COMMIT KERNEL_BRANCH KERNEL_REV <<<"${PI_KERNELS[$KERNEL_VERSION]}"

	# using rpi-update to fetch and install kernel and firmware
	log "Fetching SHA: ${KERNEL_COMMIT} from branch: ${KERNEL_BRANCH}" "info"
	RpiUpdate_args=("UPDATE_SELF=0" "SKIP_WARNING=1" "SKIP_BACKUP=1" "SKIP_CHECK_PARTITION=1"
		"WANT_32BIT=1" "WANT_64BIT=1" "WANT_PI2=1" "WANT_PI4=1"
		"WANT_PI5=1" "WANT_16K=0" "WANT_64BIT_RT=0"
	)
	log "Adding kernel ${KERNEL_VERSION} using rpi-update" "info"
	env "${RpiUpdate_args[@]}" "${ROOTFSMNT}"/usr/bin/rpi-update "${KERNEL_COMMIT}"

	log "Adding Custom firmware from github" "info"
	for key in "${!CustomFirmware[@]}"; do
		wget -nv "${CustomFirmware[$key]}" -O "$key.tar.gz" || {
			log "Failed to get firmware:" "err" "${key}"
			rm "$key.tar.gz"
			continue
		}
		tar --strip-components 1 --exclude "*.hash" --exclude "*.md" -xf "$key.tar.gz"
		rm "$key.tar.gz"
	done

	# Remove RPi0/RPi1 kernel
	if [ -d "/lib/modules/${KERNEL_VERSION}+" ]; then
		log "Removing ${KERNEL_VERSION}+ Kernel and modules" "info"
		rm -rf /boot/kernel.img
		rm -rf "/lib/modules/${KERNEL_VERSION}+"
	fi

	# Remove RPi2 kernel
	if [ -d "/lib/modules/${KERNEL_VERSION}-v7+" ]; then
		log "Removing ${KERNEL_VERSION}-v7+ Kernel and modules" "info"
		rm -rf /boot/kernel7.img
		rm -rf "/lib/modules/${KERNEL_VERSION}-v7+"
	fi

	# Remove RPi3/RPi4 32bit kernel
	if [ -d "/lib/modules/${KERNEL_VERSION}-v7l+" ]; then
		log "Removing ${KERNEL_VERSION}-v7l+ Kernel and modules" "info"
		rm -rf /boot/kernel7l.img
		rm -rf "/lib/modules/${KERNEL_VERSION}-v7l+"
	fi

	# Remove Pi5 16K kernel
	if [ -d "/lib/modules/${KERNEL_VERSION}-v8_16k+" ]; then
		log "Removing ${KERNEL_VERSION}-v8_16k+ Kernel and modules" "info"
		rm -rf /boot/kernel_2712.img
		rm -rf "/lib/modules/${KERNEL_VERSION}-v8_16k+"
	fi
	if [ -d "/lib/modules/${KERNEL_VERSION}-v8-16k+" ]; then
		log "Removing v8-16k+ (Pi5 16k) Kernel and modules" "info"
		rm -rf /boot/kernel_2712.img
		rm -rf "/lib/modules/${KERNEL_VERSION}-v8-16k+"
	fi

	# Remove 64-bit realtime kernel
	if [[ -d "/lib/modules/${KERNEL_VERSION}-v8-rt+" ]]; then
		log "Removing v8-rt+ (64bit RT) Kernel and modules" "info"
		rm -f /boot/kernel_2712_rt.img
		rm -rf "/lib/modules/${KERNEL_VERSION}-v8-rt+"
	fi

	# Remove all unintended +rpt-rpi-* variants
	for kdir in /lib/modules/*; do
		kbase=$(basename "$kdir")
		if [[ "$kbase" == *+rpt-rpi-* ]]; then
			log "Removing stray kernel module folder: $kbase" "info"
			rm -rf "/lib/modules/$kbase"
		fi
	done

	# Remove any empty module folders
	for kdir in /lib/modules/${KERNEL_VERSION}*; do
		if [[ -d "$kdir" && ! -f "$kdir/modules.builtin" ]]; then
			kbase=$(basename "$kdir")
			log "Removing empty kernel module folder: $kbase" "info"
			rm -rf "$kdir"
		fi
	done

	log "Finished Kernel installation" "okay"

	### Other Rpi specific stuff
	log "Installing fake libraspberrypi0 package" "info"
	wget -nv https://github.com/volumio/volumio3-os-static-assets/raw/master/custom-packages/libraspberrypi0/libraspberrypi0_1.20230509-buster-1_armhf.deb
	dpkg -i libraspberrypi0_1.20230509-buster-1_armhf.deb
	rm libraspberrypi0_1.20230509-buster-1_armhf.deb
	### Plymouth backport
	# TODO: Temporary only, backport for drm DSI rotation
	if [[ "${VARIANT}" == motivo ]]; then
		log "Installing custom backport plymouth packages" "info"
		wget -nv https://github.com/volumio/volumio3-os-static-assets/raw/master/custom-packages/plymouth/01libplymouth5_0.9.5-4_arm.deb
		wget -nv https://github.com/volumio/volumio3-os-static-assets/raw/master/custom-packages/plymouth/02plymouth_0.9.5-4_arm.deb
		wget -nv https://github.com/volumio/volumio3-os-static-assets/raw/master/custom-packages/plymouth/plymouth-label_0.9.5-4_arm.deb
		dpkg -i *plymouth*_0.9.5-4_arm.deb
		rm *plymouth*_0.9.5-4_arm.deb
		# Block upgrade of libplymouth from raspi repos
		log "Blocking libplymouth upgrades from raspi repos" "info"
		cat <<-EOF >"${ROOTFSMNT}/etc/apt/preferences.d/libplymouth"
			Package: libplymouth4
			Pin: release *
			Pin-Priority: -1
		EOF
	fi

	## Lets update some packages from raspbian repos now
	apt-get update && apt-get -y upgrade

	NODE_VERSION=$(node --version)
	log "Node version installed:" "dbg" "${NODE_VERSION}"
	# drop the leading v
	NODE_VERSION=${NODE_VERSION:1}
	if [[ ${USE_NODE_ARMV6:-yes} == yes && ${NODE_VERSION%%.*} -ge 8 ]]; then
		log "Using a compatible nodejs version for all pi images" "info"
		# We don't know in advance what version is in the repo, so we have to hard code it.
		# This is temporary fix - make this smarter!
		declare -A NodeVersion=(
			[14]="https://repo.volumio.org/Volumio2/nodejs_14.15.4-1unofficial_armv6l.deb"
			[8]="https://repo.volumio.org/Volumio2/nodejs_8.17.0-1unofficial_armv6l.deb"
		)
		# TODO: Warn and proceed or exit the build?
		local arch=armv6l
		wget -nv "${NodeVersion[${NODE_VERSION%%.*}]}" -P /volumio/customNode || log "Failed fetching Nodejs for armv6!!" "wrn"
		# Proceed only if there is a deb to install
		if compgen -G "/volumio/customNode/nodejs_*-1unofficial_${arch}.deb" >/dev/null; then
			# Get rid of armv7 nodejs and pick up the armv6l version
			if dpkg -s nodejs &>/dev/null; then
				log "Removing previous nodejs installation from $(command -v node)" "info"
				log "Removing Node $(node --version) arm_version: $(node <<<'console.log(process.config.variables.arm_version)')" "info"
				apt-get -y purge nodejs
			fi
			log "Installing Node for ${arch}" "info"
			dpkg -i /volumio/customNode/nodejs_*-1unofficial_${arch}.deb
			log "Installed Node $(node --version) arm_version: $(node <<<'console.log(process.config.variables.arm_version)')" "info"
			rm -rf /volumio/customNode
		fi
		# Block upgrade of nodejs from raspi repos
		log "Blocking nodejs upgrades for ${NODE_VERSION}" "info"
		cat <<-EOF >"${ROOTFSMNT}/etc/apt/preferences.d/nodejs"
			Package: nodejs
			Pin: release *
			Pin-Priority: -1
		EOF
	fi

	log "Adding gpio & spi group and permissions" "info"
	groupadd -f --system gpio
	groupadd -f --system spi

	log "Disabling sshswitch" "info"
	rm /etc/sudoers.d/010_pi-nopasswd
	unlink /etc/systemd/system/multi-user.target.wants/sshswitch.service
	rm /lib/systemd/system/sshswitch.service

	log "Changing external ethX priority" "info"
	# As built-in eth _is_ on USB (smsc95xx or lan78xx drivers)
	sed -i 's/KERNEL==\"eth/DRIVERS!=\"smsc95xx\", DRIVERS!=\"lan78xx\", &/' /etc/udev/rules.d/99-Volumio-net.rules

	log "Adding volumio to gpio,i2c,spi group" "info"
	usermod -a -G gpio,i2c,spi,input volumio

	log "Handling Video Core quirks" "info"

	log "Adding /opt/vc/lib to linker" "info"
	cat <<-EOF >/etc/ld.so.conf.d/00-vmcs.conf
		/opt/vc/lib
	EOF
	log "Updating LD_LIBRARY_PATH" "info"
	ldconfig

	log "Symlinking vc bins" "info"
	# https://github.com/RPi-Distro/firmware/blob/debian/debian/libraspberrypi-bin.links
	VC_BINS=("edidparser" "raspistill" "raspivid" "raspividyuv" "raspiyuv"
		"tvservice" "vcdbg" "vcgencmd" "vchiq_test"
		"dtoverlay" "dtoverlay-pre" "dtoverlay-post" "dtmerge")
	for bin in "${VC_BINS[@]}"; do
		ln -s "/opt/vc/bin/${bin}" "/usr/bin/${bin}"
	done

	log "Fixing vcgencmd permissions" "info"
	cat <<-EOF >/etc/udev/rules.d/10-vchiq.rules
		SUBSYSTEM=="vchiq",GROUP="video",MODE="0660"
	EOF

	# Rename gpiomem in udev rules if kernel is equal or greater than 6.1.54
	if [ "$MAJOR_VERSION" -gt 6 ] || { [ "$MAJOR_VERSION" -eq 6 ] && { [ "$MINOR_VERSION" -gt 1 ] || [ "$MINOR_VERSION" -eq 1 ] && [ "$PATCH_VERSION" -ge 54 ]; }; }; then
		log "Rename gpiomem in udev rules" "info"
		sed -i 's/bcm2835-gpiomem/gpiomem/g' /etc/udev/rules.d/99-com.rules
	fi

	log "Setting bootparms and modules" "info"
	log "Enabling i2c-dev module" "info"
	echo "i2c-dev" >>/etc/modules

	log "Writing config.txt file" "info"
	cat <<-EOF >/boot/config.txt
		### DO NOT EDIT THIS FILE ###
		### APPLY CUSTOM PARAMETERS TO userconfig.txt ###
		initramfs volumio.initrd
		gpu_mem=256
		dtparam=ant2
		max_framebuffers=1
		disable_splash=1
		force_eeprom_read=0
		dtparam=audio=off
		start_x=1
		include volumioconfig.txt
		include userconfig.txt
	EOF

	log "Writing volumioconfig.txt file" "info"
	cat <<-EOF >/boot/volumioconfig.txt
		### DO NOT EDIT THIS FILE ###
		### APPLY CUSTOM PARAMETERS TO userconfig.txt ###
		display_auto_detect=1
		enable_uart=1
		arm_64bit=1
		dtparam=uart0=on
		dtparam=uart1=off
		dtoverlay=dwc2,dr_mode=host
		otg_mode=1
		dtoverlay=vc4-kms-v3d,cma-384,audio=off,noaudio=on
	EOF

	log "Writing cmdline.txt file" "info"

	# Build up the base parameters
	# Prepare kernel_params placeholder
	kernel_params=(
	)
	# Prepare Volumio splash, quiet, debug and loglevel.
	# In init, "splash" controls Volumio logo, but in debug mode it will still be present
	# In init, "quiet" had no influence (unused), but in init{v2,v3} it will prevent initrd console output
	# So, when debugging, remove it and update loglevel to value: 8
	if [[ $DEBUG_IMAGE == yes ]]; then
		log "Debug image: remove splash from cmdline.txt" "cfg"
		SHOW_SPLASH="nosplash" # Debug removed
		log "Debug image: remove quiet from cmdline.txt" "cfg"
		KERNEL_QUIET="" # Debug removed
		log "Debug image: change loglevel to value: 8, debug, break and kmsg in cmdline.txt" "cfg"
		KERNEL_LOGLEVEL="loglevel=8 debug break= use_kmsg=yes" # Default Debug
	else
		log "Default image: add splash to cmdline.txt" "cfg"
		SHOW_SPLASH="splash" # Default splash enabled
		log "Default image: add quiet to cmdline.txt" "cfg"
		KERNEL_QUIET="quiet" # Default quiet enabled
		log "Default image: change loglevel to value: 0, nodebug, no break  and no kmsg in cmdline.txt" "cfg"
		KERNEL_LOGLEVEL="loglevel=0 nodebug use_kmsg=no" # Default to KERN_EMERG
	fi
	# Show splash
	kernel_params+=("${SHOW_SPLASH}")
	# Boot screen stuff
	kernel_params+=("plymouth.ignore-serial-consoles")
	# Raspi USB controller params
	# TODO: Check if still required!
	# Prevent Preempt-RT lock up
	kernel_params+=("dwc_otg.fiq_enable=1" "dwc_otg.fiq_fsm_enable=1" "dwc_otg.fiq_fsm_mask=0xF" "dwc_otg.nak_holdoff=1")
	# Hide kernel's stdio
	kernel_params+=("${KERNEL_QUIET}")
	# Output console device and options.
	kernel_params+=("console=serial0,115200" "console=tty1")
	# Image params
	kernel_params+=("imgpart=UUID=${UUID_IMG} imgfile=/volumio_current.sqsh bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA} uuidconfig=cmdline.txt")
	# A quirk of Linux on ARM that may result in suboptimal performance
	kernel_params+=("pcie_aspm=off" "pci=pcie_bus_safe")
	# Wait for root device
	kernel_params+=("rootwait" "bootdelay=7")
	# Disable linux logo during boot
	kernel_params+=("logo.nologo")
	# Disable cursor
	kernel_params+=("vt.global_cursor_default=0")

	# Buster tweaks
	DISABLE_PN="net.ifnames=0"
	kernel_params+=("${DISABLE_PN}")
	# ALSA tweaks
	kernel_params+=("snd-bcm2835.enable_compat_alsa=1")

	# Further debug changes
	if [[ $DEBUG_IMAGE == yes ]]; then
		log "Creating debug image" "dbg"
		log "Adding Serial Debug parameters" "dbg"
		echo "include debug.txt" >>/boot/config.txt
		cat <<-EOF >/boot/debug.txt
			# Enable serial console for boot debugging
			enable_uart=1
		EOF
		log "Enabling SSH" "dbg"
		touch /boot/ssh
		if [[ -f /boot/bootcode.bin ]]; then
			log "Enable serial boot debug" "dbg"
			sed -i -e "s/BOOT_UART=0/BOOT_UART=1/" /boot/bootcode.bin
		fi
	fi

	kernel_params+=("${KERNEL_LOGLEVEL}")
	log "Setting ${#kernel_params[@]} Kernel params:" "${kernel_params[*]}" "info"
	cat <<-EOF >/boot/cmdline.txt
		${kernel_params[@]}
	EOF

	# Rerun depmod for new drivers
	if [ -d "/lib/modules/${KERNEL_VERSION}-v8+" ]; then
		log "Finalising drivers installation with depmod on ${KERNEL_VERSION}-v8+"
		depmod "${KERNEL_VERSION}-v8+" # CM4 with 64bit kernel
	fi
	log "CM4 Kernel and Modules installed" "okay"
}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
	# log "Running device_chroot_tweaks_post" "ext"
	:
}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
	log "Running device_image_tweaks_post" "ext"
    # Plymouth systemd services OVERWRITE
	if [[ "${UPDATE_PLYMOUTH_SERVICES_FOR_KMS_DRM}" == yes ]]; then
        log "Updating plymouth systemd services" "info"
        cp -dR "${SRC}"/volumio/framebuffer/systemd/* "${ROOTFSMNT}"/lib/systemd
	fi
}
