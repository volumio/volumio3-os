#!/usr/bin/env bash
# shellcheck disable=SC2034

DEVICE_SUPPORT_TYPE="C" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="T"       # First letter (Planned|Test|Maintenance)

# Import the NanoPi H3 based family configuration
# shellcheck source=./recipes/devices/families/nanopi-armbian_h3.sh
source "${SRC}"/recipes/devices/families/nanopi-armbian_h3.sh

### Device information
DEVICENAME="NanoPi Neo" # Pretty name
