#!/usr/bin/env bash
# Prepare rootfs prior to chroot config

set -eo pipefail
function exit_error() {
	log "Volumio config failed" "err" "echo ""${1}" "$(basename "$0")"""
}

trap 'exit_error ${LINENO}' INT ERR

log "Preparing for chroot configuration" "info"

# Apt sources
log "Creating Apt lists for ${BASE}"
AptComponents=("main" "contrib" "non-free")
[[ ${BASE} == "Debian" ]] && AptComponents+=("non-free-firmware")
[[ ${BASE} == "Raspbian" ]] && AptComponents+=("rpi")
log "Setting repo to ${APTSOURCE[${BASE}]} ${SUITE} ${AptComponents[*]}"
cat <<-EOF >"${ROOTFS}/etc/apt/sources.list"
	deb ${APTSOURCE[${BASE}]} ${SUITE} ${AptComponents[*]}
	# Uncomment line below then 'apt-get update' to enable 'apt-get source'
	#deb-src ${APTSOURCE[${BASE}]} ${SUITE} ${AptComponents[*]}
EOF

if [[ ${USE_EXTRA_REPOS:-no} == yes ]] && [[ ${BASE} == "Debian" ]]; then
	cat <<-EOF >>"${ROOTFS}/etc/apt/sources.list"
		# Additional security and backport repos
		deb ${APTSOURCE[${BASE}]} ${SUITE}-updates main contrib non-free
		#deb-src ${APTSOURCE[${BASE}]} ${SUITE}-updates main contrib non-free

		deb ${APTSOURCE[${BASE}]} ${SUITE}-backports main contrib non-free
		#deb-src ${APTSOURCE[${BASE}]} ${SUITE}-backports main contrib non-free

		deb http://security.debian.org/debian-security ${SUITE}-security main contrib non-free
		#deb-src http://security.debian.org/debian-security ${SUITE}-security main contrib non-free
	EOF
fi