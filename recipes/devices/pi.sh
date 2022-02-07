#!/usr/bin/env bash
# shellcheck disable=SC2034
## Setup for Raspberry Pi
DEVICE_SUPPORT_TYPE="S" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Base system
BASE="Raspbian"
ARCH="armhf"
BUILD="arm"

### Device information
# Used to identify devices (VOLUMIO_HARDWARE) and keep backward compatibility
#VOL_DEVICE_ID="pi"
DEVICENAME="Raspberry Pi"
# This is useful for multiple devices sharing the same/similar kernel
#DEVICEFAMILY="raspberry"

# Disable to ensure the script doesn't look for `platform-xxx`
#DEVICEREPO=""

### What features do we want to target
# TODO: Not fully implemented
VOLVARIANT=no # Custom Volumio (Motivo/Primo etc)
MYVOLUMIO=no
VOLINITUPDATER=yes

## Partition info
BOOT_START=0
BOOT_END=96
BOOT_TYPE=msdos  # msdos or gpt
INIT_TYPE="init" # init.{x86/nextarm/nextarm_tvbox}

# Modules that will be added to intramfs
MODULES=("overlay" "squashfs")
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
	EOF

	log "Fetching rpi-update" "info"
	curl -L --output "${ROOTFSMNT}/usr/bin/rpi-update" https://raw.githubusercontent.com/volumio/rpi-update/master/rpi-update &&
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
	)
	# Version we want
	KERNEL_VERSION="5.10.92"

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
	echo y | SKIP_BACKUP=1 WANT_PI4=1 SKIP_CHECK_PARTITION=1 UPDATE_SELF=0 BRANCH=${KERNEL_BRANCH} /usr/bin/rpi-update "${KERNEL_COMMIT}"

	if [ -d "/lib/modules/${KERNEL_VERSION}-v8+" ]; then
		log "Removing v8+ (pi4) Kernels" "info"
		rm /boot/kernel8.img
		rm -rf "/lib/modules/${KERNEL_VERSION}-v8+"
	fi

        if [ "$ KERNEL_VERSION" = "5.4.83" ]; then
          ### Temporary fix for Rasbperry PI 1.5
          ### We use this as kernel 5.10.89 does not work with some USB DACs preventing latest kernel to be used
          log "Downloading Firmware to support PI4 v 1.5"
	  wget -O /boot/bcm2708-rpi-b-plus.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2708-rpi-b-plus.dtb
          wget -O /boot/bcm2708-rpi-b-rev1.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2708-rpi-b-rev1.dtb
          wget -O /boot/bcm2708-rpi-b.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2708-rpi-b.dtb
          wget -O /boot/bcm2708-rpi-cm.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2708-rpi-cm.dtb
          wget -O /boot/bcm2708-rpi-zero-w.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2708-rpi-zero-w.dtb
          wget -O /boot/bcm2708-rpi-zero.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2708-rpi-zero.dtb
          wget -O /boot/bcm2709-rpi-2-b.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2709-rpi-2-b.dtb
          wget -O /boot/bcm2710-rpi-2-b.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2710-rpi-2-b.dtb
          wget -O /boot/bcm2710-rpi-3-b-plus.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2710-rpi-3-b-plus.dtb
          wget -O /boot/bcm2710-rpi-3-b.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2710-rpi-3-b.dtb
          wget -O /boot/bcm2710-rpi-cm3.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2710-rpi-cm3.dtb
          wget -O /boot/bcm2710-rpi-zero-2-w.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2710-rpi-zero-2-w.dtb
          wget -O /boot/bcm2710-rpi-zero-2.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2710-rpi-zero-2.dtb
          wget -O /boot/bcm2711-rpi-4-b.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2711-rpi-4-b.dtb
          wget -O /boot/bcm2711-rpi-400.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2711-rpi-400.dtb
          wget -O /boot/bcm2711-rpi-cm4.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2711-rpi-cm4.dtb
          wget -O /boot/bcm2711-rpi-cm4s.dtb https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bcm2711-rpi-cm4s.dtb
          wget -O /boot/bootcode.bin https://github.com/raspberrypi/firmware/raw/9c04ed2c1ad06a615d8e6479806ab252dbbeb95a/boot/bootcode.bin
          wget -O /boot/fixup.dat https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/fixup.dat
          wget -O /boot/fixup4.dat https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/fixup4.dat
          wget -O /boot/fixup4cd.dat https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/fixup4cd.dat
          wget -O /boot/fixup4db.dat https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/fixup4db.dat
          wget -O /boot/fixup4x.dat https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/fixup4x.dat
          wget -O /boot/fixup_cd.dat https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/fixup_cd.dat
          wget -O /boot/fixup_db.dat https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/fixup_db.dat
          wget -O /boot/fixup_x.dat https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/fixup_x.dat
          wget -O /boot/start.elf https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/start.elf
          wget -O /boot/start4.elf https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/start4.elf
          wget -O /boot/start4cd.elf https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/start4cd.elf
          wget -O /boot/start4db.elf https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/start4db.elf
          wget -O /boot/start4x.elf https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/start4x.elf
          wget -O /boot/start_cd.elf https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/start_cd.elf
          wget -O /boot/start_db.elf https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/start_db.elf
          wget -O /boot/start_x.elf https://github.com/raspberrypi/firmware/raw/165bd7bc5622ee1c721aa5da9af68935075abedd/boot/start_x.elf
        fi

	log "Finished Kernel installation" "okay"

	### Other Rpi specific stuff
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

	# Fetch and install additional WiFi drivers
	WifiRepo="http://wifi-drivers.volumio.org/wifi-drivers"
	WifiDrivers=("8188eu" "8188fu" "8192eu" "8812au" "8821cu" "8822bu")
	archs=("arm-v7l" "arm-v7" "arm")
	log "Installing additional wireless drivers. Many thanks MrEngman!" "info" "${WifiDrivers[*]}"
	WifiDir=/tmp/wifi
	[[ ! -d "${WifiDir}" ]] && mkdir -p "${WifiDir}"
	pushd "${WifiDir}" || log "Can't change to ${WifiDir}" "error"
	for driver in "${WifiDrivers[@]}"; do
		for arch in "${archs[@]}"; do
			log "[${arch}] Fetching driver" "${driver}"
			archiveName=${driver}-${KERNEL_VERSION}${arch:3}-${KERNEL_REV}.tar.gz
			archiveUrl=${WifiRepo}/${driver}-drivers/${archiveName}
			# The Volumio mirror will always return a 200 code,
			# and even give you a file to download for a missing driver, so usual curl tricks won't work here..
			curl -sLO "${archiveUrl}"
			# So test the file before continuing, or gracefully move on
			[[ ! -s ${archiveName} ]] && {
				log "[${arch}] Failed fetching ${driver}" "err" "${archiveUrl}"
				continue
			}
			# Kinda messy, but the tarball doesn't always extract fully - so try and protect against that as well
			(
				tar xz -f "${archiveName}" &&
					sed -i 's|sudo ||' install.sh &&
					./install.sh &&
					log "[${arch}] Installed" "okay" "${driver}"
			) || log "[${arch}] Installation failed" "err" "${driver} -- $(stat --printf="%s" "${archiveName}")"
		done
	done
	popd || log "Can't change dir" "error"
	rm -r "${WifiDir}"

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

	log "Fixing vcgencmd permissions"
	cat <<-EOF >/etc/udev/rules.d/10-vchiq.rules
		SUBSYSTEM=="vchiq",GROUP="video",MODE="0660"
	EOF

	log "Setting bootparms and modules" "info"
	log "Enabling i2c-dev module"
	echo "i2c-dev" >>/etc/modules

	log "Writing config.txt file"
	cat <<-EOF >/boot/config.txt
		initramfs volumio.initrd
		gpu_mem=32
		max_usb_current=1
		dtparam=audio=on
		audio_pwm_mode=2
		dtparam=i2c_arm=on
		disable_splash=1
		hdmi_force_hotplug=1
		force_eeprom_read=0

		include userconfig.txt
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
		"imgpart=/dev/mmcblk0p2" "imgfile=/volumio_current.sqsh"
		# Wait for root device
		"rootwait" "bootdelay=5"
		# I/O scheduler
		"elevator=noop"
		# Disable linux logo during boot
		"logo.nologo"
		# Disable cursor
		"vt.global_cursor_default=0"
	)

	# Buster tweaks
	kernel_params+=("${DISABLE_PN}")
	# ALSA tweaks
	# ALSA compatibility needs to be set depending on kernel version,
	# so use hacky semver check here in the odd case we want to go back to a lower kernel
	[[ ${KERNEL_SEMVER[0]} == 5 ]] && compat_alsa=0 || compat_alsa=1
	# https://github.com/raspberrypi/linux/commit/88debfb15b3ac9059b72dc1ebc5b82f3394cac87
	if [[ ${KERNEL_SEMVER[0]} == 5 ]] && [[ ${KERNEL_SEMVER[2]} -le 4 ]] && [[ ${KERNEL_SEMVER[2]} -le 79 ]]; then
		kernel_params+=("snd_bcm2835.enable_headphones=1")
	fi
	kernel_params+=("snd-bcm2835.enable_compat_alsa=${compat_alsa}" "snd_bcm2835.enable_hdmi=1")

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
	depmod "${KERNEL_VERSION}-v7l+" # Pi4

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
