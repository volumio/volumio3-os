

## Auto Installer image
**Create**
```
./mkinstaller.sh -i <location of the volumio image>
```

where currently supported devices are  **Volumio Rivo/Primo/Integro**, **Khadas VIM1S**, **Odroid N2** **Odroid M1S** and **RockPi 4B**

NOTE: Due to limited image filename parsing options, the board name is only allowed to have a maximum of one single dash, like "rockpi-4b".
With more than one, the installer will not work!


**Use**
- Flash the Auto installer to an SD card
- Insert the SD card in the target device
- Power the target device
- Wait until finished (after 30-40 secs the devices leds should be steady)


## How it works

Basically, the installer creates the 3 standard partitions on the target devices, as specified in the build recipe, for the data partition it takes the rest of the disk. does.  Then it copies the bootpartition and the image partition files. 

The installer is made up of 5 components:

**mkinstaller.sh**  
This is the main build script.
It creates an autoinstaller image with 
- a kernel
- an initramfs (incl. scripts and config)
- the tarbal with the contents of the volumio image's boot partition
- the volumiocurrent.sqsh
- the bootloader files (u-boot)

**mkinstaller_config.sh**  
Device-specific mkinstaller configuration and script functions

**mkinitrd.sh**  
A build script running in chroot.  
It creates the runtime, board-specific initramfs, which acts as the "autoinstaller" 

 
**initramfs**
It is board-specific and is made up of:   

It mounts the boot partiton of the autoinstaller, loads the necessary modules, checks whether UUID are used and checks whether the target disk device is present.
When the target disk device is present, the installer 
- clears all existing partitions
- creates the boot and imgpart partitions according to the config
- the data partiton with the remaining of the disk device

It then 
- mounts the 3 partitions 
- in the boot partition it unpacks the boot partiton tarbal 
- copies the .sqsh file to the image partition

When UUIDs are used in the boot configuration, they will be replaced by the ones from the newly created partitions.

Process start and finish will be notified by the led functions (board-specific).   

**board-functions**  
These are the board-specific function, used by the init scripts.
Example: write_device_bootloader, which is different for most boards.

## Installer creation ##

The main part of the installer is generic, these parts are *mkinstaller.sh*, *mkinitrd.sh* (which creates the initramfs), they do not change.
To make the installer board-specific, two specific scripts are needed, *board-functions* and "mkinstall_config.sh"
These scripts need to be placed in the *board-config* folder, in a subfolder with the name of the board.
To explain how this is done, the creation of an installer for the Rock Pi 4B is taken as an example and described below


 # How to add a new installer

This looks more complicated than it actually is.
Most of the functionality is already there and creating your device-specific installer only takes two files to be copied from an existing installer and modified.
Most of the information you need was already configured in the board's recipe.
With this example, the Rock PI 4B, you will need the "rockpi-4b.sh" device recipe as a reference.

First create folder ```rockpi-4b``` in the installer's ```board-config``` folder
```
installer
  |
  +--board-config
      |
      +---rockpi-4b
```
Note: the folder name must match the boards name as used in it's recipe.
Then copy from any of the exisiting board configurastion the two scripts ```board-functions``` and ```mkinstall_config.sh```.
We will use these as templates, I used the ones from odroidm1s as they came closest
```
installer
  |
  +--board-config
      |
      +--rockpi-4b
          |
          +--board-functions
          +--mkinstall_config.sh
```

# Script ```mkinstall_config.sh```
- Start with the ```mkinstall_config.sh``` file, you need rockpi-4b.sh as a reference.  
Modify the following parameters, some may have the correct values already.

|Parameter|New content|Comment|
|---|---|---|
|DEVICEBASE|rock4
|BOARDFAMILY|rockpi-4b
PLATFORMREPO|https://github.com/volumio/platform-${DEVICEBASE}.git"
BOOT_START|20
BOOT_END|148
BOOTDEV|mmcblk0|Check this by booting from an SD card and then see which device you booted from and which one is your target disk (with eMMC it is the one with the special boot0 and boot1 partitions). Use this info for the following TARGET parameters
BOOTDEVICE|/dev/mmcblk0p1
BOOTCONFIG|armbianEnv.txt
TARGETBOOT|/dev/mmcblk1p1|Used by the installer image
TARGETDEV|/dev/mmcblk1|Used by the installer image
TARGETDATA|dev/mmcblk1p3|Used by the installer image
TARGETIMAGE|/dev/mmcblk1p2|Used by the installer image
MODULES|"nls_cp437 fuse"|To be safe, match this with your build recipe. But omit overlay, overlayfs and squashfs, the installer does not need them.
HWDEVICE|rockpi-4b|Used by the installer image

- Next in ```mkinstall_config.sh```, re-write the board-specific functions.  
For ```write_device_files()```, just copy the needed basic files for booting, no need for an overlay or any other board-specific run-time content.  
  
```
write_device_files()
{
  cp ${PLTDIR}/${BOARDFAMILY}/boot/Image ${ROOTFSMNT}/boot
  cp ${PLTDIR}/${BOARDFAMILY}/boot/armbianEnv.txt ${ROOTFSMNT}/boot
  cp ${PLTDIR}/${BOARDFAMILY}/boot/boot.scr ${ROOTFSMNT}/boot
  cp -dR ${PLTDIR}/${BOARDFAMILY}/boot/dtb ${ROOTFSMNT}/boot
} 
```
- For ```write_device_bootloader()```, refer to ```rockpi-4b.sh```
```
write_device_bootloader()
{
  dd if=${PLTDIR}/${BOARDFAMILY}/u-boot/idbloader.img of=${LOOP_DEV} seek=64 conv=notrunc status=none
  dd if=${PLTDIR}/${BOARDFAMILY}/u-boot/u-boot.itb of=${LOOP_DEV} seek=16384 conv=notrunc status=none
}
```
- For ```copy_device_bootloader_files()```, refer to ```rockpi-4b.sh```
```
copy_device_bootloader_files()
{
   mkdir ${ROOTFSMNT}/boot/u-boot
   cp ${PLTDIR}/${BOARDFAMILY}/u-boot/idbloader.img $ROOTFSMNT/boot/u-boot
   cp ${PLTDIR}/${BOARDFAMILY}/u-boot/u-boot.itb $ROOTFSMNT/boot/u-boot
}
```
- For ```write_boot_parameters()```, refer to platform template ```armbianEnv.txt```.  
Only very basic data is needed, it is only to start into initramfs. There is no rootfs to load.
Console information can be helpful for debugging, note that at the end of the process you can issue the "dmesg" command to check.
```
write_boot_parameters()
{
   sed -i "s/verbosity/#verbosity/g" $ROOTFSMNT/boot/armbianEnv.txt
   sed -i "s/imgpart=UUID= bootpart=UUID= datapart=UUID= bootconfig=armbianEnv.txt imgfile=\/volumio_current.sqsh net.ifnames=0/loglevel=0/g" $ROOTFSMNT/boot/armbianEnv.txt
   sed -i "s/user_overlays=spdif_sound//g" $ROOTFSMNT/boot/armbianEnv.txt
}
```  

# Script ```board_functions```
The next script to modify is ```board_functions```  
This one has 4 script, of which only one is crucial: ```write_device_bootloader()```

```
write_device_bootloader()
{
   echo "[info] Flashing u-boot"
   dd if=${BOOT}/u-boot/idbloader.img of=$1 seek=64 conv=notrunc status=none
   dd if=${BOOT}/u-boot/u-boot.itb of=$1 seek=16384 conv=notrunc status=none
}
```

The other 3 functions are used to play with the leds while the installer is running.
It is very board-specific, some boards only have a power led, which you cannot even switch off. Others are a bit more flexible, most ones have at least with a heartbeat/on/off function, some have two different colored leds.  
This part is up to someone's imagination.  
Try to indicate at least start and stop, so the user has some idea when the process is finished.   