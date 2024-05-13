#!/usr/bin/env bash
# shellcheck disable=SC2034

DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Import the NanoPi H5 based family configuration
# shellcheck source=./recipes/devices/families/nanopi-armbian_h5.sh
source "${SRC}"/recipes/devices/families/nanopi-armbian_h5.sh

### Device information
DEVICENAME="NanoPi Neo2" # Pretty name
DISABLE_DISPLAY=yes
