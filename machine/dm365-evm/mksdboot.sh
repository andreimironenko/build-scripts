#! /bin/sh
# Script to create SD card for DM365 plaform.
#
# Author: Andrei Mironenko
#

VERSION="0.4"

execute ()
{
    $* >/dev/null
    if [ $? -ne 0 ]; then
        echo
        echo "ERROR: executing $*"
        echo
        exit 1
    fi
}

usage ()
{
  echo "
Usage: `basename $1` [options] --device <device> 

Mandatory options:

  --ubl    [filename]   	UBL image (mandatory) 
  --uboot  [filename]     	U-BOOT image (mandatory)
  --rootfs [filename]     	Linux root file system tarball (mandatory)
  --kernel [filename]     	Linux kernel image (mandatory)
  --kernel-modules [filename]   Kernel modules tarball (mandatory)
  --root-part-size  [size]      Root partition size in MBytes. 
                                It should be in a form of N x 1024 and
                                be big enough to accomodate linux root
                                file system image. If it's not defined,
                                default is the size of root file system
                                image + 15%.
  --user-part-size  [size]      User partition size in MBytes. 
                                It should be in a form of N x 1024.
  --user-part-lable [label]     User partition size label.
                        
Optional options:

  --help                        Print this help message.
"
  exit 1
}

declare -rx SCRIPT=${0##*/}
declare UBL=""
declare UBOOT=""
declare ROOTFS=""
declare KERNEL=""
declare KERNEL_MODULES=""
declare -i ROOT_PART_SIZE=0
declare -i USER_PART_SIZE=0
declare USER_PART_LABEL=""
declare DEVICE=""


# Make sure there is at least one parameter or accessing $1
# later will be an error.
if [ $# -eq 0 ] ; then
 printf "%s\n" "Please specify ubl, uboot, rootfs and kernel image,"
 printf "%s\n" "./$SCRIPT --help for help."
 exit 192
fi


# Process command line...
while [ $# -gt 0 ]; do
  case $1 in
    --help | -h)
      usage $SCRIPT
      ;;
    --ubl)                   shift; UBL=$1; shift; ;;
    --uboot)                 shift; UBOOT=$1; shift; ;;
    --rootfs)                shift; ROOTFS=$1; shift; ;;
    --kernel)                shift; KERNEL=$1; shift; ;;
    --kernel-modules)        shift; KERNEL_MODULES=$1; shift ;;
    --root-part-size)        shift; ROOT_PART_SIZE=$1; shift; ;;
    --user-part-size)        shift; USER_PART_SIZE=$1; shift; ;;
    --user-part-label)       shift; USER_PART_LABEL=$1; shift;  ;;
    --device)                shift; DEVICE=$1; shift; ;;
     _*)                     printf "%s\n" "Switch not supported" >&2; exit 192; ;;
      *)                     printf "%s\n" "Extra argument or missing switch" >&2; exit 192; ;;  
esac
done

#Sanity check for mandatory parameters
if [ -z "$UBL" ] ; then
   printf "%s\n" "Warning: UBL image is not provided, " >&2
   printf "%s\n" "use default value" >&2
   UBL="ubl/ubl_DM36x_sdmmc_ARM270_DDR216_OSC24.bin"
fi

if [ -z "$UBOOT" ] ; then
   printf "%s\n" "Warngin: UBOOT image is not provided," >&2
   printf "%s\n" "use default value" >&2
   UBOOT="u-boot-dm365-htc.bin"
fi

if [ -z "$ROOTFS" ] ; then
   printf "%s\n" "Warngin: root file system image is not provided, " >&2
   printf "%s\n" "use default value" >&2
   ROOTFS="htc-image.d01-dm365-htc.tar.gz"
fi

if [ -z "$KERNEL" ] ; then
   printf "%s\n" "Warning: linux kernel image is not provided," >&2
   printf "%s\n" "use default value" >&2
   KERNEL="uImage-dm365-htc.bin"
fi

if [ -z "$KERNEL_MODULES" ] ; then
   printf "%s\n" "Warning: linux kernel modules is not provided," >&2
   printf "%s\n" "use default value" >&2
   KERNEL_MODULES="modules-dm365-htc.tgz"
fi

if [ $ROOT_PART_SIZE = 0 ] ; then 
   printf "%s\n" "Warning: root partition size is not provided," >&2
   ROOT_PART_SIZE="256"
   printf "%s\n" "use default value $ROOT_PART_SIZE MBytes" >&2
fi

if [ $USER_PART_SIZE = 0 ] ; then 
   printf "%s\n" "Warning: user partition size is not provided," >&2
   printf "%s\n" "the whole space left after root partition will be used." >&2
fi

if [ -z "$USER_PART_LABEL" ] ; then 
   printf "%s\n" "Warning: user partition label is not provided," >&2
   USER_PART_LABEL="user"
   printf "%s\n" "use default value: $USER_PART_LABEL" >&2
fi
    

if [ -z "$DEVICE" ] ; then
   printf "%s\n" "Mandatory SD device parameter is missed" >&2
   exit 1
fi

# Sanity check of the files existence before continue
if [ ! -f $UBL ] ; then
  echo "ERROR: UBL image is not found"
  exit 1 
fi

if [ ! -f $UBOOT ] ; then
  echo "ERROR: U-boot image is not found"
  exit 1 
fi

if [ ! -f $ROOTFS ] ; then
  echo "ERROR: Root file system image is not found"
  exit 1 
fi

if [ ! -f $KERNEL ] ; then
  echo "ERROR: Kernel image is not found"
  exit 1 
fi

if [ ! -f $KERNEL_MODULES ] ; then
  echo "ERROR: Kernel modules archive is not found"
  exit 1 
fi

if [ ! -b $DEVICE ] ; then
  echo "ERROR: $DEVICE is not a block device file"
  exit 1 
fi


echo "************************************************************"
echo " Creating HTC boot SD card:"
echo "************************************************************"
echo "  ubl: $UBL"
echo "  uboot: $UBOOT"
echo "  rootfs: $ROOTFS"
echo "  kernel: $KERNEL"
echo "  modules:$KERNEL_MODULES"
echo "  root-part-size:  $ROOT_PART_SIZE"
echo "  user-part-size:  $USER_PART_SIZE"
echo "  user-part-label: $USER_PART_LABEL"
echo "************************************************************"
echo "*         THIS WILL DELETE ALL THE DATA ON $DEVICE        *"
echo "*                                                          *"
echo "*         WARNING! Make sure your computer does not go     *"
echo "*                  in to idle mode while this script is    *"
echo "*                  running. The script will complete,      *"
echo "*                  but your SD card may be corrupted.      *"
echo "*                                                          *"
echo "*        Do you want to continue (Y/N)?:                   *" 
echo "************************************************************"

while  true; do
  read REPLY
  if [ "$REPLY" = "y" -o "$REPLY" = "Y" ] ; then
    break
  elif [ "$REPLY" = "n" -o "$REPLY" = "N" ] ; then
    echo "Bye ..."
    exit 0
  else
    echo "Use Y/N:"
    continue
  fi
done


echo "************************************************************"
echo "* Creating SD card partitions                              *"
echo "************************************************************"

SD_SIZE=`sudo fdisk -l $DEVICE | grep Disk | awk '{print $5}'`
SD_CYLN=`echo $SD_SIZE/255/63/512 | bc`
CYLN_SIZE_BYTES=$(($SD_SIZE/$SD_CYLN))

echo "SD card characteristics:"
echo "    size $SD_SIZE bytes"
echo "    $SD_CYLN cylinders"
echo "    cylinder size $CYLN_SIZE_BYTES bytes"

echo ""
echo "Assuming here, the SD cards are used - 2G/4G/8G/16G/32G"
echo "one cylinder should be enough for the boot area"

BOOT_SIZE_CYLNS=1


echo "Unmount all partitions"
for i in `ls -1 $DEVICE?`; do
 umount $i 2>/dev/null
done

echo "Removing existing partition..."
dd if=/dev/zero of=$DEVICE bs=512 count=1 conv=notrunc

echo "Creating new partitions..."

#Get the root file system size
if [ $ROOT_PART_SIZE = 0 ] ; then
 echo "Root partition size is not specified"
 echo "use "
 echo " gzip -l rootfilesystem.tar.gz"
 echo "to get the size"
 exit 1
fi

echo "Root file system size $ROOT_PART_SIZE MBytes"

ROOT_SIZE_CYLNS=$((($ROOT_PART_SIZE*1024*1024)/$CYLN_SIZE_BYTES))
echo "Root file system size $ROOT_SIZE_CYLNS cylinders"

USER_PART_SIZE=$(($SD_SIZE - $ROOT_PART_SIZE*1024*1024))
USER_SIZE_CYLNS=$((($USER_PART_SIZE/$CYLN_SIZE_BYTES) - 1))
echo "User partition size $(($USER_PART_SIZE/(1024*1024))) MBytes"
echo "User partition size $USER_SIZE_CYLNS cylinders"

{
 echo "2,$USER_SIZE_CYLNS,0x0B,-"
 echo "$(($USER_SIZE_CYLNS+2)),$ROOT_SIZE_CYLNS,,-"
} | sfdisk --heads 255 --sectors 63 --cylinders $SD_CYLN $DEVICE



echo "Format root file system as ext3"
execute "mkfs.ext3 -L "rootfs" ${DEVICE}2"
echo "Format user FAT32 partition"
execute "mkfs.vfat -F 32 -n $USER_PART_LABEL ${DEVICE}1" 

echo "Executing mkimage utilty to create a boot.scr file"
./mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n 'Execute uImage' -d ./boot.cmd ./boot.scr

if [ $? -ne 0 ]; then
  echo "Failed to execute mkimage to create boot.scr"
  echo "Execute 'sudo apt-get install uboot-mkimage' to install the package"
  exit 1
fi
 

echo "Copy UBL and U-Boot to the boot cylinder"
./uflash -d $DEVICE -u $UBL -b $UBOOT -p DM3XX -vv

echo "Mount root file system partition"
ROOTFS_DIR="/media/tmprootfs"
mkdir -p $ROOTFS_DIR  
mount ${DEVICE}2 $ROOTFS_DIR 

echo "Untar root file system ..."
tar xvfz $ROOTFS -C $ROOTFS_DIR 
echo "Remove symlink /boot/uImage"
rm $ROOTFS_DIR/boot/uImage
echo "Copy kernel image"
cp $KERNEL $ROOTFS_DIR/boot/uImage

echo "Copy boot.scr"
cp ./boot.scr $ROOTFS_DIR/boot

echo "Untar kernel modules"
tar xvfz $KERNEL_MODULES -C $ROOTFS_DIR 

echo "Create safemode file under root directory"
touch $ROOTFS_DIR/safemode

sync

umount $ROOTFS_DIR 
rm -rf $ROOTFS_DIR

exit 0
