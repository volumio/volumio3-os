
# Current compatible

|Board name/ recipe|initv3|plymouth|
|---|---|---|
x86| yes| yes
RPi| yes| yes
mp1| yes| yes
odroidn2| yes| yes 
odroidc4| yes| yes 
odroidm1s| yes| yes
nanopineo2| yes|no (no video-out)
nanopineo3| yes|no (no video-out)
nanopim4| yes| yes
rockpi-4b| yes| yes
|||Add new boards as we proceed testing

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
