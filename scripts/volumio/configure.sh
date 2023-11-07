#!/bin/bash
##
#Volumio system Configuration Script
##

set -eo pipefail
function exit_error() {
  log "Volumio config failed" "err" "echo ""${1}" "$(basename "$0")"""
}

trap 'exit_error $LINENO' INT ERR

log "Copying Custom Volumio System Files" "info"

# Apt sources
log "Creating Apt lists for ${BASE}"
AptComponents=("main" "contrib" "non-free")
[[ $BASE == "Raspbian" ]] && AptComponents+=("rpi")
log "Setting repo to ${APTSOURCE[${BASE}]} ${SUITE} ${AptComponents[*]}"
cat <<-EOF >"${ROOTFS}/etc/apt/sources.list"
deb ${APTSOURCE[${BASE}]} ${SUITE} ${AptComponents[*]}
# Uncomment line below then 'apt-get update' to enable 'apt-get source'
#deb-src ${APTSOURCE[${BASE}]} ${SUITE} ${AptComponents[*]}
EOF

log "Copying ${BUILD} related Configuration files"
if [[ ${BUILD:0:3} == arm ]]; then
  log 'Setting time for ARM devices with fakehwclock to build time'
  date -u '+%Y-%m-%d %H:%M:%S' >"${ROOTFS}/etc/fake-hwclock.data"
fi

log "Copying misc config/tweaks to rootfs" "info"
cp -pr --no-preserve=ownership "${SRC}"/volumio/* "${ROOTFS}"/
log 'Done Copying Custom Volumio System Files' "okay"
