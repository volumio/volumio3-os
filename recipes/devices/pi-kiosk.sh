#!/usr/bin/env bash
# shellcheck disable=SC2034

### Setup for <OEM_PI> device
DEVICE_SUPPORT_TYPE="S" # First letter (Community Porting|Supported Officially|OEM)
DEVICE_STATUS="M"       # First letter (Planned|Test|Maintenance)

# Import the base family configuration
# shellcheck source=./recipes/devices/pi.sh
source "${SRC}"/recipes/devices/pi.sh

# Enable kiosk
KIOSKMODE=yes
KIOSKBROWSER=vivaldi

# We need a bigger image size
BOOT_END=180
IMAGE_END=3800
