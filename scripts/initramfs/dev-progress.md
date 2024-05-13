
# Current compatible

|Board name/ recipe|initv3|plymouth|UUID done|OTA working
|---|---|---|---|---|
bananapim1 | yes | yes | bootdev | yes
bananapipro | yes | yes | bootdev | yes
cm4 | yes | yes | yes | yes
mp0 | yes | yes | yes | yes
mp1 | yes | yes | yes | yes
nanopim4 | yes | yes | yes | yes
nanopineo2-a | yes | no (no video-out) | bootdev | yes
nanopineo2 | yes | no (no video-out) | bootdev | yes
nanopineo3 | yes | no (no video-out) | bootdev | yes
odroidc4 | yes | yes | yes | yes
odroidm1s | yes | yes | yes | yes
odroidn2 | yes | yes | yes | yes
orangepilite | yes | yes | bootdev | skipped
orangepione | yes | yes | bootdev | ?
orangepipc | yes | yes | bootdev | skipped
Rpi | yes | yes | yes | ?
radxa-zero2 | yes | yes | yes | yes
radxa-zero | yes | yes | yes | yes
rkbox_h96max | yes | yes | yes | yes
rkbox_hk1 | yes | yes | yes | yes
rkbox_t9 | yes | yes | yes | yes
rkbox_x88pro | yes | yes | yes | yes
rock-3a | yes | yes | yes | yes
rockpi-4b | yes | yes | yes | yes
rockpie | yes | no (no video-out) | yes | yes
rockpis | yes | no (no video-out) | yes | yes
tinkerboard | yes | yes | yes | ?
vmod-a0 | yes | no (no video-out) | yes | yes
x86 | yes | yes | yes | yes
|||||Add new boards as we proceed testing

# Recipes modifications

## Environment variables
INIT_TYPE=initv3  
Selection of plymouth themes:
PLYMOUTH_THEME="volumio-logo"
PLYMOUTH_THEME="volumio-player" (default)

## Add initv3 custom functions
Some devices use initv3 custom functions, eg. x86 and pi (more could follow).

|Board|init script addition in function "device_image_tweaks()|
|---|---|
||```log "Copying custom initramfs script functions"```
||```[ -d ${ROOTFSMNT}/root/scripts ] \|\| mkdir ${ROOTFSMNT}/root/scripts```
||followed by device-specific custom functions
|x86|```cp "${SRC}/scripts/initramfs/custom/x86/custom-functions" ${ROOTFSMNT}/root/scripts```
|pi|```cp "${SRC}/scripts/initramfs/custom/pi/custom-functions" ${ROOTFSMNT}/root/scripts```
|non-uuid devices|```cp "${SRC}/scripts/initramfs/custom/non-uuid-devices/custom-functions" ${ROOTFSMNT}/root/scripts```

## Custom functions placeholder in ```volumio-functions```
|Name|Device|actions in custom-functions|
|---|---|---|
|custom_init_partition_params()|pi|After upgrade from block device UUID will not be active yet. Use genpnames|
|custom_update_UUID()|pi|Configurations change from block device to "disk/by-UUID"|
|validate_imgfile_imgpart()|x86|x86 uses two config parameters

## Default kernel parameters
|Support type|Parameter (group)
|---|---|
|plymouth default|"splash" "plymouth.ignore-serial-consoles" "initramfs.clear" (preferred order)
|initv3 default|"quiet loglevel=0" (must-be order acc. some documentation)
|initv3 default|"use_kmsg=no"
|initv3 default|"hwdevice=```${DEVICE}```" (nice-to-have, currently unused. Perhaps initv3 should read it from ```/etc/os-release``` like it does ```${VOLUMIO_VERSION}```)
|initv3 default|**ALL** boards using "UUID=": replace ```bootconfig```by ```uuidconfig``` (bootconfig is a reserved param, this should be corrected with initv3)
||Add new boards as we proceed with testing||
