
# Current compatible

|Board|initv3|plymouth|
|---|---|---|
x86| yes|yes
RPi| yes|yes
(odroidn2) |yes| untested 
Nanopi Neo2|untested|no (no video-out)
Nanopi Neo3|untested|no (video-out)
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

## Custom functions placeholder in ```volumio-functions```
|Name|Device|actions in custom-functions|
|---|---|---|
|custom_init_partition_params()|pi|After upgrade from block device UUID will not be active yet. Use genpnames|
|custom_update_UUID()|pi|Configurations change from block device to "disk/by-UUID"|

## Default kernel parameters
|Support type|Parameter (group)
|---|---|
|plymouth default|"splash" "plymouth.ignore-serial-consoles" "initramfs.clear" (preferred order)
|initv3 default|"quiet loglevel=0" (must-be order acc. some documentation)
|initv3 default|"use_kmsg=no"
|initv3 default|"hwdevice=```${DEVICE}```" (nice-to-have, currently unused. Perhaps initv3 should read it from ```/etc/os-release``` like it does ```${VOLUMIO_VERSION}```)
|initv3 default|All boards: replace ```bootconfig```by ```uuidconfig``` (bootconfig is a reserved param, this should be corrected with initv3)
||Add new boards as we proceed with testing||
