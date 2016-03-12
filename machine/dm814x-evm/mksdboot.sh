#! /bin/sh
################################################################################
#  Global variables                                                            #
################################################################################

#Getting our own script name
declare -rx SCRIPT=${0##*/}

declare SCRIPT_PATH=`pwd`
declare ROOTFS_PATH="$SCRIPT_PATH/../rootfs"
declare TFTP_PATH="$SCRIPT_PATH/../tftp"

declare ROOT_SIZE="0"
declare USER_SIZE="0"
declare USER_LABEL="data"
declare BOOT_LABEL="boot"
declare ROOT_LABEL="rootfs"

declare UBOOT_MIN="u-boot.min.sd"
declare UBOOT="u-boot.sd.bin"
declare UIMAGE="uImage"


# The execute function is used to pick up the result of operation and stop the
# execution of the script in case failure. Consider it as an analogue of 
# C/C++ assert
execute () 
{
	$* >/dev/null
    if [ $? -ne 0 ]; then
        echo
        echo "ERROR: executing $*"
        echo
        exit -1
    fi
}


# Process command line...
while [ $# -gt 0 ]; do
  case $1 in
    --help | -h) 
    printf "%s\n"             
    printf "%s\n" "Start creating booting card for DM8148"
	printf "%s\n"
	printf "%s\n" "Usage: $SCRIPT [options] device"
	printf "%s\n"
	printf "%s\n" "Available options:"
	printf "%s\t%s\n" "--root-part-size  [size]" "Root partition size in MBytes." 
    printf "\t%s\n"            "It should be in a form of N x 1024 and"
    printf "\t%s\n"            "be big enough to accomodate linux root"
	printf "\t%s\n"            "file system image. If it is not defined,"       
	printf "\t%s\n"            "default is the size of root file system"
    printf "\t%s\n"            "image + 30%"
	printf "%s\n"
	printf "%s\t%s\n" "--user-part-size  [size]" "User FAT32 partition size in MBytes." 
    printf "\t%s\n"                             "It should be in a form of N x 1024"
    printf "\t%s\n"                             "If it's not defined, occupies all free space"
    printf "\t%s\n"                             "left after boot and rootfs partitions"
	printf "%s\n"
	printf "%s\t%s\n" "--user-part-label [size]" "User partition label" 
	printf "%s\t%s\n" "-h, --help" "This help"
	printf "%s\n"
	printf "%s\n" "Example"
	printf "%s\n" "Allocating 1 GByte for root files system and the rest"
	printf "%s\n" "will be used for user FAT32 partition"
	printf "%s\n" "$SCRIPT --root-part-size 1024 /dev/sdb  "
	printf "%s\n"
	exit 0
    ;;
    --root-part-size )     shift; ROOT_SIZE=$1;  shift; ;;
    --user-part-size )     shift; USER_SIZE=$1;  shift; ;;
    --user-part-label)     shift; USER_LABEL=$1; shift; ;;
    -*)                 printf "%s\n" "Switch not supported" >&2; exit -1 ;;
    *)                  DEVICE=$1; shift; ;;  
esac
done


#Sanity check for parameters and export directory 
SANITY_CHECK_STATUS=1

#Check mandatory parameters first
if [ ! -b "$DEVICE" ] ; then
   printf "%s\n" "$DEVICE is not found" >&2
   SANITY_CHECK_STATUS=0
fi

if [ ! -d "${ROOTFS_PATH}" ] ; then
	printf "%s\n" "${ROOTFS_PATH} is not found, please re-run makerelease.sh" >&2
	printf "%s\n" "once again!"
	SANITY_CHECK_STATUS=0
fi

if [ ! -d "${TFTP_PATH}" ] ; then
	printf "%s\n" "${TFTP_PATH} is not found, please re-run makerelease.sh"
	printf "%s\n" "once again!"
	SANITY_CHECK_STATUS=0
fi

if [ "$SANITY_CHECK_STATUS" = "1" ] ; then
	printf "%s\n" "Sanity check for parameters and export directories ...Ok"
else
	printf "%s\n" "Sanity check for parameters and export directories ...Failed"
	exit -1 
fi

echo "************************************************************"
echo "*             Creating DM8148 boot SD card                 *"
echo "*----------------------------------------------------------*"
echo "*         THIS WILL DELETE ALL THE DATA ON $DEVICE!       *"
echo "*                                                          *"
echo "*         WARNING! Make sure your computer does not go     *"
echo "*                  into power down mode while this script  *"
echo "*                  is running, as the SD card might be     *"
echo "*                  corrupted.                              *"
echo "************************************************************"
printf "%s" "Do you want to continue (Y/N)?:" 

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

printf "\n"


printf "%s" "BOOT partition size ..."
BOOT_UIMAGE_SIZE=`du -ch -k ${TFTP_PATH}/uImage | grep total`
BOOT_UIMAGE_SIZE="${BOOT_UIMAGE_SIZE:0:5}"
let "BOOT_UIMAGE_SIZE *= 1024"

BOOT_UBOOT_MIN_SIZE=`du -ch ${TFTP_PATH}/u-boot.min.sd | grep total`
BOOT_UBOOT_MIN_SIZE="${BOOT_UBOOT_MIN_SIZE%K*}"
let "BOOT_UBOOT_MIN_SIZE *= 1024"

BOOT_UBOOT_SIZE=`du -ch ${TFTP_PATH}/u-boot.sd.bin | grep total`
BOOT_UBOOT_SIZE="${BOOT_UBOOT_SIZE%K*}"
let "BOOT_UBOOT_SIZE *= 1024"

BOOT_SCR_SIZE=`du -ch ${TFTP_PATH}/default.scr | grep total`
BOOT_SCR_SIZE="${BOOT_SCR_SIZE%K*}"
let "BOOT_SCR_SIZE *= 1024"

let "BOOT_SIZE = BOOT_UIMAGE_SIZE + BOOT_UBOOT_MIN_SIZE + BOOT_UBOOT_SIZE"
let "BOOT_SIZE = BOOT_SIZE + BOOT_SCR_SIZE"

#Add extra 30% to the initial size
let "BOOT_SIZE = BOOT_SIZE + BOOT_SIZE/3"

printf "%s\n" "$BOOT_SIZE Bytes"

printf "%s" "ROOT partition size ..."
if [ ${ROOT_SIZE} -eq "0" ] ; then
	ROOT_SIZE=`du -ch -k ${ROOTFS_PATH}| grep total`
	ROOT_SIZE="${ROOT_SIZE:0:7}"
	#let "ROOT_SIZE = ROOT_SIZE + ROOT_SIZE/3"
	# Assign ROOT_SIZE=FILE_SYSTEM_SIZE + 1G
	let "ROOT_SIZE = ROOT_SIZE + 1024*1024"
	let "ROOT_SIZE = ROOT_SIZE * 1024"
	printf "%s\n" "$ROOT_SIZE Bytes"
fi

printf "\n"
printf "%s\n" "Probing SD card ..."

SD_SIZE=`sudo fdisk -l $DEVICE | grep Disk | awk '{print $5}'`
SD_CYLN=`echo $SD_SIZE/255/63/512 | bc`
CYLN_SIZE_BYTES=$(($SD_SIZE/$SD_CYLN))

echo "SD card characteristics:"
echo "    size $SD_SIZE bytes"
echo "    heads 255"
echo "    sectors 63"
echo "    $SD_CYLN cylinders"
echo "    cylinder size $CYLN_SIZE_BYTES bytes"

printf "\n"
printf "%s\n" "Calculating partitions sizes"

printf "%s" "BOOT partition size in cylinders ..."
let "BOOT_SIZE_CYLNS = BOOT_SIZE / CYLN_SIZE_BYTES + 1"
if [ $BOOT_SIZE_CYLNS -lt 5 ] ; then
	BOOT_SIZE_CYLNS=5
fi 
printf "%s\n" "$BOOT_SIZE_CYLNS"

printf "%s" "ROOT partition size in cylinders ... "
let "ROOT_SIZE_CYLNS = ROOT_SIZE / CYLN_SIZE_BYTES + 1"
printf "%s\n" "$ROOT_SIZE_CYLNS"

let "REMINDER_SIZE_CYLNS = SD_CYLN - BOOT_SIZE_CYLNS - ROOT_SIZE_CYLNS"

printf "%s" "USER partition size in cylinders ..."

if [ "$USER_SIZE" -eq "0" ] ; then
	let "USER_SIZE_CYLNS = REMINDER_SIZE_CYLNS"
else
	let "USER_SIZE_CYLNS = (USER_SIZE * 1024)/CYLN_SIZE_BYTES"
fi

if [ "$USER_SIZE_CYLNS" -gt "$REMINDER_SIZE_CYLNS" ] ; then
	printf "%s\n" "Too big!"
	printf "%s\n" "User partition is too big!"
	let "AVAILABLE_SPACE = (USER_SIZE_CYLNS * CYLN_SIZE_BYTES)/1024"
	printf "%s\n" "Requested size $USER_SIZE, available space $AVAILABLE_SPACE MBytes"
	printf "%s\n" "Change this parameter and re-run script again"
	exit -1
fi
printf "%s\n" "$USER_SIZE_CYLNS"

printf "%s\n"
echo "************************************************************"
echo "* Creating SD card partitions                              *"
echo "************************************************************"
printf "%s\n"

printf "%s" "Unmount all partitions ... "
for i in `ls -1 $DEVICE?`; do
 umount $i 2>/dev/null
done
printf "%s\n" "Ok"

printf "%s" "Removing existing partition..."
dd if=/dev/zero of=$DEVICE bs=512 count=1 conv=notrunc
printf "%s\n" "OK"

printf "Creating new partitions..."

{
 echo ",$BOOT_SIZE_CYLNS,0x0C,*"
 echo ",$ROOT_SIZE_CYLNS,,-"
 echo ",$USER_SIZE_CYLNS,0x0B,-"
} | sfdisk --heads 255 --sectors 63 --cylinders $SD_CYLN $DEVICE


if [ $? -ne 0 ]; then
 echo sfdisk has failed returning $?
 exit 1;
fi

printf "\n%s" "Formating BOOT partition..."
execute "mkfs.vfat -F 32 -n "${BOOT_LABEL}" ${DEVICE}1"
printf "%s\n" "Ok"

printf "%s" "Formating ROOT partition..."
execute "mkfs.ext3 -j -L "${ROOT_LABEL}" ${DEVICE}2"
printf "%s\n" "Ok"

printf "%s" "Formating USER partition..."
execute "mkfs.vfat -F 32 -n "${USER_LABEL}" ${DEVICE}3"
printf "%s\n" "Ok"

printf "%s" "Mount all SD partitons ..."
execute "mkdir -p /media/${BOOT_LABEL}"
execute "mkdir -p /media/${ROOT_LABEL}"
execute "mkdir -p /media/${USER_LABELE}"
execute "mount ${DEVICE}1 /media/${BOOT_LABEL}"
execute "mount ${DEVICE}2 /media/${ROOT_LABEL}"
execute "mount ${DEVICE}3 /media/${USER_LABEL}"
printf "%s\n" "Ok"

printf "%s" "Untaring root file system to ROOT partition of SD card ..." 
execute "tar xvzf ../rootfs.tar.gz -C /media/${ROOT_LABEL}"
printf "%s\n" "Ok"

printf "%s" "Copying MLO (u-boot.min) to SD ..."
execute "cp ${TFTP_PATH}/${UBOOT_MIN} /media/${BOOT_LABEL}/MLO"
printf "%s\n" "OK"

printf "%s" "Copying $UBOOT image to SD..."
execute "cp ${TFTP_PATH}/${UBOOT} /media/${BOOT_LABEL}/u-boot.bin"
printf "%s\n" "OK"

printf "%s" "Copying $UIMAGE image ..."
execute "cp ${TFTP_PATH}/${UIMAGE} /media/${BOOT_LABEL}/"
printf "%s\n" "OK"

printf "%s\n" "Creating boot.scr ..."
cat <<EOF > ./boot.cmd
setenv bootargs 'console=ttyO0,115200n8 rootwait root=/dev/mmcblk0p2 rw mem=364M@0x80000000 mem=320M@0x9FC00000 vmalloc=500M  notifyk.vpssm3_sva=0xBF900000 ip=off noinitrd'
fatload mmc 0 0x80009000 uImage
bootm 0x80009000
EOF
mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n 'Execute uImage.bin' -d ./boot.cmd /media/${BOOT_LABEL}/boot.scr
rm ./boot.cmd

printf "%s" "Umouting all parttions ..."
execute "umount /media/${BOOT_LABEL}"
execute "umount /media/${ROOT_LABEL}"
execute "umount /media/${USER_LABEL}"

execute "rm -rf /media/${BOOT_LABEL}"
execute "rm -rf /media/${ROOT_LABEL}"
execute "rm -rf /media/${USER_LABEL}"
printf "%s\n" "OK"

printf "%s\n" "SD boot card is ready, remove it!"

exit 0 

