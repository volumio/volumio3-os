#!/bin/bash

source /config.sh
# shellcheck source=./scripts/helpers.sh
source /helpers.sh
export -f log
if [ ! "x${PACKAGES}" == "x" ]; then
   log "[Stage 2] Adding board-specific packages" "info"
   apt-get update
   apt-get install -y "${PACKAGES}"
fi

log "[Stage 2] Adding custom modules" "info"
echo "" > /etc/initramfs-tools/modules
for module in ${MODULES}
do 
   echo $module >> /etc/initramfs-tools/modules
done

# #mke2fsfull is used since busybox mke2fs does not include ext4 support
cp -rp /sbin/mke2fs /sbin/mke2fsfull

log "[Stage 2] Creating initramfs 'volumio.initrd'" "info"
mkinitramfs-custom.sh -o /tmp/initramfs-tmp



