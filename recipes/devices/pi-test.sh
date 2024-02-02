#!/usr/bin/env bash
# shellcheck disable=SC2034

## Setup for Raspberry Pi
DEVICE_SUPPORT_TYPE="S" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="P"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Raspbian"
ARCH="armhf"
BUILD="arm"

### Device information
# Used to identify devices (VOLUMIO_HARDWARE) and keep backward compatibility
#VOL_DEVICE_ID="pi"
DEVICENAME="Raspberry Pi"
# This is useful for multiple devices sharing the same/similar kernel
DEVICEFAMILY="raspberry"

# Disable to ensure the script doesn't look for `platform-xxx`
DEVICEREPO="https://github.com/volumio/platform-${DEVICEFAMILY}.git"

### What features do we want to target
# TODO: Not fully implemented
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes

## Partition info
BOOT_START=0
BOOT_END=96
BOOT_TYPE=msdos  # msdos or gpt
BOOT_USE_UUID=yes        # Add UUID to fstab
INIT_TYPE="init.nextarm" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to initramfs
MODULES=("overlay" "squashfs" "fuse" "nvme" "nvme_core" "uas")
# Packages that will be installed
PACKAGES=(# Bluetooth packages
	"bluez" "bluez-firmware" "pi-bluetooth"
	# Foundation stuff
	"raspberrypi-sys-mods"
	# "rpi-eeprom"\ Needs raspberrypi-bootloader that we hold back
	# GPIO stuff
	"wiringpi"
	# Boot splash
	"plymouth" "plymouth-themes"
	# Wireless firmware
	"firmware-atheros" "firmware-ralink" "firmware-realtek" "firmware-brcm80211"
	# Install to disk tools
	"liblzo2-2" "squashfs-tools"
)

### Device customisation
# Copy the device specific files (Image/DTS/etc..)
write_device_files() {
	log "Running write_device_files" "ext"
	log "Copying additional utils files"
	pkg_root="${PLTDIR}/utils"

	mkdir -p "${ROOTFSMNT}"/usr/local/bin/
		declare -A CustomScripts=(
    	[PiInstaller.sh]="/PiInstaller.sh"
	)
	log "Adding ${#CustomScripts[@]} custom scripts to /usr/local/bin: " "" "${CustomScripts[@]}"
		for script in "${!CustomScripts[@]}"; do
    		cp "${pkg_root}/${CustomScripts[$script]}" "${ROOTFSMNT}"/usr/local/bin/"${script}"
    		chmod +x "${ROOTFSMNT}"/usr/local/bin/"${script}"
  		done

	log "Copying current partition data for use in runtime fast 'installToDisk'"
	cat <<-EOF >"${ROOTFSMNT}/boot/partconfig.json"
{
  "params":[
  {"name":"boot_start","value":"$BOOT_START"},
  {"name":"boot_end","value":"$BOOT_END"},
  {"name":"volumio_end","value":"$IMAGE_END"},
  {"name":"boot_type","value":"$BOOT_TYPE"}
  ]
}
	EOF
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

	log "Fixing hostapd.conf"
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

	log "Adding archive.raspberrypi debian repo"
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
	log "Blocking raspberrypi-bootloader and raspberrypi-kernel"
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

	log "Fetching rpi-update" "info"
	curl -L --output "${ROOTFSMNT}/usr/bin/rpi-update" https://raw.githubusercontent.com/volumioteam/rpi-update/master/rpi-update &&
		chmod +x "${ROOTFSMNT}/usr/bin/rpi-update"
	#TODO: Look into moving kernel stuff outside chroot using ROOT/BOOT_PATH to speed things up
	# ROOT_PATH=${ROOTFSMNT}
	# BOOT_PATH=${ROOT_PATH}/boot
}

# Will be run in chroot (before other things)
device_chroot_tweaks() {
	log "Running device_image_tweaks" "ext"
	# rpi-update needs binutils
	log "Installing binutils for rpi-update"
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
		[4.19.86]="b9ecbe8d0e3177afed08c54fc938938100a0b73f|master|1283"
		[4.19.97]="993f47507f287f5da56495f718c2d0cd05ccbc19|master|1293"
		[4.19.118]="e1050e94821a70b2e4c72b318d6c6c968552e9a2|master|1311"
		[5.4.51]="8382ece2b30be0beb87cac7f3b36824f194d01e9|master|1325"
		[5.4.59]="caf7070cd6cece7e810e6f2661fc65899c58e297|master|1336"
		[5.4.79]="0642816ed05d31fb37fc8fbbba9e1774b475113f|master|1373"
		[5.4.81]="453e49bdd87325369b462b40e809d5f3187df21d|master|1379" # Looks like uname_string wasn't updated here..
		[5.4.83]="b7c8ef64ea24435519f05c38a2238658908c038e|stable|1379"
		[5.10.3]="da59cb1161dc7c75727ec5c7636f632c52170961|master|1386"
		[5.10.73]="1597995e94e7ba3cd8866d249e6df1cf9a790e49|master|1470"
		[5.10.90]="9a09c1dcd4fae55422085ab6a87cc650e68c4181|master|1512"
		[5.10.92]="ea9e10e531a301b3df568dccb3c931d52a469106|stable|1514"
		[5.10.95]="770ca2c26e9cf341db93786d3f03c89964b1f76f|master|1521"
		[5.15.84]="a99e144e939bf93bbd03e8066601a8d3eae640f7|stable|1613"
		[5.15.92]="f5c4fc199c8d8423cb427e509563737d1ac21f3c|master|1627"
		[6.1.19]="fa51258e0239eaf68d9dff9c156cec3a622fbacc|stable|1637"
		[6.1.21]="f87ad1a3cb8c81e32dc3d541259291605ddaada0|stable|1642"
		[6.1.47]="f87ad1a3cb8c81e32dc3d541259291605ddaada0|stable|1674"
		[6.1.57]="12833d1bee03c4ac58dc4addf411944a189f1dfd|master|1688" # Support for Pi5
		[6.1.58]="7b859959a6642aff44acdfd957d6d66f6756021e|master|1690"
		[6.1.61]="d1ba55dafdbd33cfb938bca7ec325aafc1190596|master|1696"
		[6.1.64]="01145f0eb166cbc68dd2fe63740fac04d682133e|master|1702"
		[6.1.70]="fc9319fda550a86dc6c23c12adda54a0f8163f22|master|1712"
	)
	# Version we want
	KERNEL_VERSION="6.1.70"

	MAJOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d '.' -f 1)
	MINOR_VERSION=$(echo "$KERNEL_VERSION" | cut -d '.' -f 2)
	PATCH_VERSION=$(echo "$KERNEL_VERSION" | cut -d '.' -f 3)

	# For bleeding edge, check what is the latest on offer
	# Things *might* break, so you are warned!
	if [[ ${RPI_USE_LATEST_KERNEL:-no} == yes ]]; then
		branch=master
		log "Using bleeding edge Rpi kernel" "info" "$branch"
		RpiRepo="https://github.com/raspberrypi/rpi-firmware"
		RpiRepoApi=${RpiRepo/github.com/api.github.com\/repos}
		RpiRepoRaw=${RpiRepo/github.com/raw.githubusercontent.com}
		log "Fetching latest kernel details from ${RpiRepo}"
		RpiGitSHA=$(curl --silent "${RpiRepoApi}/branches/${branch}")
		readarray -t RpiCommitDetails <<<"$(jq -r '.commit.sha, .commit.commit.message' <<<"${RpiGitSHA}")"
		log "Rpi latest kernel -- ${RpiCommitDetails[*]}"
		# Parse required info from `uname_string`
		uname_string=$(curl --silent "${RpiRepoRaw}/${RpiCommitDetails[0]}/uname_string")
		RpiKerVer=$(awk '{print $3}' <<<"${uname_string}")
		KERNEL_VERSION=${RpiKerVer/+/}
		RpiKerRev=$(awk '{print $1}' <<<"${uname_string##*#}")
		PI_KERNELS[${KERNEL_VERSION}]+="${RpiCommitDetails[0]}|${branch}|${RpiKerRev}"
		# Make life easier
		log "Using rpi-update SHA:${RpiCommitDetails[0]} Rev:${RpiKerRev}" "${KERNEL_VERSION}"
		log "[${KERNEL_VERSION}]=\"${RpiCommitDetails[0]}|${branch}|${RpiKerRev}\"" "debug"
	fi

	# List of custom firmware -
	# github archives that can be extracted directly
	declare -A CustomFirmware=(
		[AlloPiano]="https://github.com/allocom/piano-firmware/archive/master.tar.gz"
		[TauDAC]="https://github.com/taudac/modules/archive/rpi-volumio-${KERNEL_VERSION}-taudac-modules.tar.gz"
		[Bassowl]="https://raw.githubusercontent.com/Darmur/bassowl-hat/master/driver/archives/modules-rpi-${KERNEL_VERSION}-bassowl.tar.gz"
		[wm8960]="https://raw.githubusercontent.com/hftsai256/wm8960-rpi-modules/main/wm8960-modules-rpi-${KERNEL_VERSION}.tar.gz"
	)

	### Kernel installation
	IFS=\. read -ra KERNEL_SEMVER <<<"${KERNEL_VERSION}"
	IFS=\| read -r KERNEL_COMMIT KERNEL_BRANCH KERNEL_REV <<<"${PI_KERNELS[$KERNEL_VERSION]}"

	# using rpi-update to fetch and install kernel and firmware
	log "Adding kernel ${KERNEL_VERSION} using rpi-update" "info"
	log "Fetching SHA: ${KERNEL_COMMIT} from branch: ${KERNEL_BRANCH}"
	echo y | SKIP_BACKUP=1 WANT_32BIT=1 WANT_64BIT=1 WANT_PI4=1 WANT_PI5=0 SKIP_CHECK_PARTITION=1 UPDATE_SELF=0 BRANCH=${KERNEL_BRANCH} /usr/bin/rpi-update "${KERNEL_COMMIT}"

	log "Adding Custom DAC firmware from github" "info"
	for key in "${!CustomFirmware[@]}"; do
		wget -nv "${CustomFirmware[$key]}" -O "$key.tar.gz" || {
			log "Failed to get firmware:" "err" "${key}"
			rm "$key.tar.gz"
			continue
		}
		tar --strip-components 1 --exclude "*.hash" --exclude "*.md" -xf "$key.tar.gz"
		rm "$key.tar.gz"
	done

	## Comment to keep RPi4/RPi5 64bit kernel
	#if [ -d "/lib/modules/${KERNEL_VERSION}-v8+" ]; then
	#	log "Removing v8+ (Pi4/5) Kernel and modules" "info"
	#	rm -rf /boot/kernel8.img
	#	rm -rf "/lib/modules/${KERNEL_VERSION}-v8+"
	#fi

	## Comment to keep RPi5 64bit 16k page size kernel
	if [ -d "/lib/modules/${KERNEL_VERSION}-v8_16k+" ]; then
		log "Removing v8_16k+ (Pi5 16k) Kernel and modules" "info"
		rm -rf /boot/kernel_2712.img
		rm -rf "/lib/modules/${KERNEL_VERSION}-v8_16k+"
	fi

	log "Finished Kernel installation" "okay"

	### Other Rpi specific stuff
	log "Installing fake libraspberrypi0 package"
	wget -nv  https://github.com/volumio/volumio3-os-static-assets/raw/master/custom-packages/libraspberrypi0/libraspberrypi0_1.20230509-buster-1_armhf.deb
	dpkg -i libraspberrypi0_1.20230509-buster-1_armhf.deb
	rm libraspberrypi0_1.20230509-buster-1_armhf.deb

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
				log "Removing previous nodejs installation from $(command -v node)"
				log "Removing Node $(node --version) arm_version: $(node <<<'console.log(process.config.variables.arm_version)')" "info"
				apt-get -y purge nodejs
			fi
			log "Installing Node for ${arch}"
			dpkg -i /volumio/customNode/nodejs_*-1unofficial_${arch}.deb
			log "Installed Node $(node --version) arm_version: $(node <<<'console.log(process.config.variables.arm_version)')" "info"
			rm -rf /volumio/customNode
		fi
		# Block upgrade of nodejs from raspi repos
		log "Blocking nodejs upgrades for ${NODE_VERSION}"
		cat <<-EOF >"${ROOTFSMNT}/etc/apt/preferences.d/nodejs"
			Package: nodejs
			Pin: release *
			Pin-Priority: -1
		EOF
	fi

	log "Starting Raspi platform tweaks" "info"
	plymouth-set-default-theme volumio

	log "Adding gpio & spi group and permissions"
	groupadd -f --system gpio
	groupadd -f --system spi

	log "Disabling sshswitch"
	rm /etc/sudoers.d/010_pi-nopasswd
	unlink /etc/systemd/system/multi-user.target.wants/sshswitch.service
	rm /lib/systemd/system/sshswitch.service

	log "Changing external ethX priority"
	# As built-in eth _is_ on USB (smsc95xx or lan78xx drivers)
	sed -i 's/KERNEL==\"eth/DRIVERS!=\"smsc95xx\", DRIVERS!=\"lan78xx\", &/' /etc/udev/rules.d/99-Volumio-net.rules

	log "Adding volumio to gpio,i2c,spi group"
	usermod -a -G gpio,i2c,spi,input volumio

	log "Handling Video Core quirks" "info"

	log "Adding /opt/vc/lib to linker"
	cat <<-EOF >/etc/ld.so.conf.d/00-vmcs.conf
		/opt/vc/lib
	EOF
	log "Updating LD_LIBRARY_PATH"
	ldconfig

	log "Symlinking vc bins"
	# https://github.com/RPi-Distro/firmware/blob/debian/debian/libraspberrypi-bin.links
	VC_BINS=("edidparser" "raspistill" "raspivid" "raspividyuv" "raspiyuv"
		"tvservice" "vcdbg" "vcgencmd" "vchiq_test"
		"dtoverlay" "dtoverlay-pre" "dtoverlay-post" "dtmerge")
	for bin in "${VC_BINS[@]}"; do
		ln -s "/opt/vc/bin/${bin}" "/usr/bin/${bin}"
	done

	log "Fixing vcgencmd permissions"  "info"
	cat <<-EOF >/etc/udev/rules.d/10-vchiq.rules
		SUBSYSTEM=="vchiq",GROUP="video",MODE="0660"
	EOF

	# Rename gpiomem in udev rules if kernel is equal or greater than 6.1.54
	if [ "$MAJOR_VERSION" -gt 6 ] || { [ "$MAJOR_VERSION" -eq 6 ] && { [ "$MINOR_VERSION" -gt 1 ] || [ "$MINOR_VERSION" -eq 1 ] && [ "$PATCH_VERSION" -ge 54 ]; }; }; then
		log "Rename gpiomem in udev rules"  "info"
		sed -i 's/bcm2835-gpiomem/gpiomem/g' /etc/udev/rules.d/99-com.rules
	fi

	log "Setting bootparms and modules" "info"
	log "Enabling i2c-dev module"
	echo "i2c-dev" >>/etc/modules

	log "Writing config.txt file"
	cat <<-EOF >/boot/config.txt
		### DO NOT EDIT THIS FILE ###
		### APPLY CUSTOM PARAMETERS TO userconfig.txt ###
		initramfs volumio.initrd

		include volumioconfig.txt
		include userconfig.txt
	EOF

	log "Writing volumioconfig.txt file"
	cat <<-EOF >/boot/volumioconfig.txt
		### DO NOT EDIT THIS FILE ###
		### APPLY CUSTOM PARAMETERS TO userconfig.txt ###
		[cm4]
		dtoverlay=dwc2,dr_mode=host
		[pi5]
		dtoverlay=vc4-kms-v3d-pi5
		dtparam=uart0_console
		dtparam=nvme
		dtparam=pciex1_gen=2
		[all]
		arm_64bit=0
		gpu_mem=32
		max_usb_current=1
		dtparam=audio=on
		audio_pwm_mode=2
		dtparam=i2c_arm=on
		disable_splash=1
		hdmi_force_hotplug=1
		force_eeprom_read=0
	EOF

	log "Writing cmdline.txt file"
	KERNEL_LOGLEVEL="loglevel=0" # Default to KERN_EMERG
	DISABLE_PN="net.ifnames=0"
	# Build up the base parameters
	kernel_params=(
		# Boot screen stuff
		"splash" "plymouth.ignore-serial-consoles"
		# Raspi USB controller params
		# TODO: Check if still required!
		"dwc_otg.fiq_enable=1" "dwc_otg.fiq_fsm_enable=1"
		"dwc_otg.fiq_fsm_mask=0xF" "dwc_otg.nak_holdoff=1"
		# Output console device and options.
		"quiet" "console=serial0,115200" "console=tty1"
		# Image params
		"imgpart=UUID=${UUID_IMG} imgfile=/volumio_current.sqsh bootpart=UUID=${UUID_BOOT} datapart=UUID=${UUID_DATA} bootconfig=cmdline.txt"
		# A quirk of Linux on ARM that may result in suboptimal performance
		"pcie_aspm=off" "pci=pcie_bus_safe"
		# Wait for root device
		"bootdelay=5"
		# Disable linux logo during boot
		"logo.nologo"
		# Disable cursor
		"vt.global_cursor_default=0"
	)

	# Buster tweaks
	kernel_params+=("${DISABLE_PN}")
	# ALSA tweaks
	kernel_params+=("snd-bcm2835.enable_compat_alsa=${compat_alsa}" "snd_bcm2835.enable_hdmi=1" "snd_bcm2835.enable_headphones=1")

	if [[ $DEBUG_IMAGE == yes ]]; then
		log "Creating debug image" "wrn"
		log "Adding Serial Debug parameters"
		echo "include debug.txt" >>/boot/config.txt
		cat <<-EOF >/boot/debug.txt
			# Enable serial console for boot debugging
			enable_uart=1
			dtoverlay=pi3-miniuart-bt
		EOF
		KERNEL_LOGLEVEL="loglevel=8" # KERN_DEBUG
		log "Enabling SSH"
		touch /boot/ssh
		if [[ -f /boot/bootcode.bin ]]; then
			log "Enable serial boot debug"
			sed -i -e "s/BOOT_UART=0/BOOT_UART=1/" /boot/bootcode.bin
		fi
	fi

	kernel_params+=("${KERNEL_LOGLEVEL}")
	log "Setting ${#kernel_params[@]} Kernel params:" "${kernel_params[*]}"
	cat <<-EOF >/boot/cmdline.txt
		${kernel_params[@]}
	EOF

	# Rerun depmod for new drivers
	log "Finalising drivers installation with depmod on ${KERNEL_VERSION}+,-v7+ and -v7l+"
	depmod "${KERNEL_VERSION}+"     # Pi 1, Zero, Compute Module
	depmod "${KERNEL_VERSION}-v7+"  # Pi 2,3 CM3
	depmod "${KERNEL_VERSION}-v7l+" # Pi 4 CM4
	depmod "${KERNEL_VERSION}-v8+"  # Pi 4,5 CM4 64bit
	#depmod "${KERNEL_VERSION}-v8_16k+"  # Pi 4,5 CM4 64bit

	log "Raspi Kernel and Modules installed" "okay"

}

# Will be run in chroot - Post initramfs
device_chroot_tweaks_post() {
	# log "Running device_chroot_tweaks_post" "ext"
	:
}

# Will be called by the image builder post the chroot, before finalisation
device_image_tweaks_post() {
	# log "Running device_image_tweaks_post" "ext"
	:
}
