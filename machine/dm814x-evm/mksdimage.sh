#! /bin/sh
source ./buildenv.sh

################################################################################
#  Global variables                                                            #
################################################################################

#Getting our own script name
declare -rx SCRIPT=${0##*/}

declare SCRIPT_PATH=`pwd`
declare DEPLOY_PATH="$SCRIPT_PATH/.."
declare ROOTFS_PATH="$DEPLOY_PATH/rootfs"
declare ROOT_SIZE="0"
declare USER_SIZE="0"
declare USER_LABEL="data"
declare BOOT_LABEL="boot"
declare ROOT_LABEL="rootfs"

declare UBOOT_PATH="$DEPLOY_PATH/u-boot"
declare UBOOT_MIN="u-boot.min.sd"
declare UBOOT="u-boot.sd.bin"
declare UIMAGE="uImage.bin"
declare KERNEL="uImage"

declare LOOP0="/dev/loop0"
declare LOOP1="/dev/loop1"
declare LOOP2="/dev/loop2"
declare EXPORT_IMAGE="$DEPLOY_PATH/${PRODUCT}.${PRODUCT_RELEASE}-${PRODUCT_VERSION}.sd.img"
declare IMAGE="$DEPLOY_PATH/sd.image"


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
	printf "%s\n" "Usage: $SCRIPT [options] image"
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
	printf "%s\n" "$SCRIPT --root-part-size 1024 sdboot.img  "
	printf "%s\n"
	exit 0
    ;;
    --root-part-size )     shift; ROOT_SIZE=$1;  shift; ;;
    --user-part-size )     shift; USER_SIZE=$1;  shift; ;;
    --user-part-label)     shift; USER_LABEL=$1; shift; ;;
    -*)                 printf "%s\n" "Switch not supported" >&2; exit -1 ;;
    *)                  IMAGE=$1; shift; ;;  
esac
done


#Sanity check for parameters and export directory 
SANITY_CHECK_STATUS=1

if [ ! -d "${ROOTFS_PATH}" ] ; then
	printf "%s\n" "${ROOTFS_PATH} is not found, please re-run makerelease.sh" >&2
	printf "%s\n" "once again!"
	SANITY_CHECK_STATUS=0
fi

if [ ! -d "${DEPLOY_PATH}" ] ; then
	printf "%s\n" "${DEPLOY_PATH} is not found, please re-run makerelease.sh"
	printf "%s\n" "once again!"
	SANITY_CHECK_STATUS=0
fi

if [ "$SANITY_CHECK_STATUS" = "1" ] ; then
	printf "%s\n" "Sanity check for parameters and export directories ...Ok"
else
	printf "%s\n" "Sanity check for parameters and export directories ...Failed"
	exit -1 
fi



printf "%s" "BOOT partition size ..."
BOOT_UIMAGE_SIZE=`du -ch -k ${DEPLOY_PATH}/${UIMAGE} | grep total`
BOOT_UIMAGE_SIZE="${BOOT_UIMAGE_SIZE:0:5}"
let "BOOT_UIMAGE_SIZE *= 1024"

BOOT_UBOOT_MIN_SIZE=`du -ch ${UBOOT_PATH}/${UBOOT_MIN} | grep total`
BOOT_UBOOT_MIN_SIZE="${BOOT_UBOOT_MIN_SIZE%K*}"
let "BOOT_UBOOT_MIN_SIZE *= 1024"

BOOT_UBOOT_SIZE=`du -ch ${UBOOT_PATH}/${UBOOT} | grep total`
BOOT_UBOOT_SIZE="${BOOT_UBOOT_SIZE%K*}"
let "BOOT_UBOOT_SIZE *= 1024"

BOOT_SCR_SIZE=`du -ch ${UBOOT_PATH}/default.cmd | grep total`
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
	#Add extra 30% to the initial size
	let "ROOT_SIZE = ROOT_SIZE + ROOT_SIZE/3"
	#Convert the size to bytes
	let "ROOT_SIZE = ROOT_SIZE * 1024"
	printf "%s\n" "$ROOT_SIZE Bytes"
fi

let "DRIVE_SIZE = BOOT_SIZE + ROOT_SIZE"
let "DRIVE_SIZE_MBYTES = DRIVE_SIZE / 1024 + 1"
printf "%s" "Total drive size ... $DRIVE_SIZE"
printf "\n"

printf "%s" "Creating ${IMAGE}"
dd if=/dev/zero of=${IMAGE} bs=1024 count=$DRIVE_SIZE_MBYTES > /dev/null
 

 
SD_SIZE=`fdisk -l $IMAGE | grep Disk | awk '{print $5}'`
SD_CYLN=`echo $SD_SIZE/255/63/512 | bc`
#CYLN_SIZE_BYTES=$(($SD_SIZE/$SD_CYLN))
CYLN_SIZE_BYTES=8225280

echo "Image characteristics:"
echo "    size $SD_SIZE bytes"
echo "    heads 255"
echo "    sectors 63"
echo "    $SD_CYLN cylinders"
echo "    cylinder size $CYLN_SIZE_BYTES bytes"

printf "\n"
printf "%s\n" "Calculating partitions sizes"

printf "%s" "BOOT partition size in cylinders ..."
let "BOOT_SIZE_CYLNS = BOOT_SIZE / CYLN_SIZE_BYTES + 1"
printf "%s\n" "$BOOT_SIZE_CYLNS"

printf "%s" "ROOT partition size in cylinders ... "
let "ROOT_SIZE_CYLNS = ROOT_SIZE / CYLN_SIZE_BYTES - 1"
printf "%s\n" "$ROOT_SIZE_CYLNS"



printf "%s\n" "Creating /dev/loop0 device for whole drive"
losetup ${LOOP0} ${IMAGE}

{
 echo ",$BOOT_SIZE_CYLNS,0x0C,*"
 echo ",$ROOT_SIZE_CYLNS,,-"
} | sfdisk --heads 255 --sectors 63 --cylinders $SD_CYLN $LOOP0


if [ $? -ne 0 ]; then
 echo sfdisk has failed returning $?
 exit 1;
fi

printf "%s\n" "Creating ${LOOP1} device with BOOT partition"
printf "%s\n" "losetup ${LOOP1} ${IMAGE} -o 512 --sizelimit $[ $BOOT_SIZE_CYLNS * $CYLN_SIZE_BYTES ]"
losetup ${LOOP1} ${IMAGE} -o 512 --sizelimit $[ $BOOT_SIZE_CYLNS * $CYLN_SIZE_BYTES - 512 ]

printf "%s\n" "Creating ${LOOP2} device with ROOTFS partition"
printf "%s\n" "losetup ${LOOP2} ${IMAGE} -o  $[ 512 + $BOOT_SIZE_CYLNS * $CYLN_SIZE_BYTES ] --sizelimit $[$ROOT_SIZE_CYLNS * $CYLN_SIZE_BYTES]"
losetup ${LOOP2} ${IMAGE} -o  $(($CYLN_SIZE_BYTES * $BOOT_SIZE_CYLNS)) --sizelimit $[ $ROOT_SIZE_CYLNS * $CYLN_SIZE_BYTES ]

mkfs.vfat -n ${BOOT_LABEL} ${LOOP1}
mkfs.ext3 -L ${ROOT_LABEL} ${LOOP2}

mkdir -p ${SCRIPT_PATH}/${BOOT_LABEL}
mkdir -p ${SCRIPT_PATH}/${ROOT_LABEL}

mount ${LOOP1} ${SCRIPT_PATH}/${BOOT_LABEL}
mount ${LOOP2} ${SCRIPT_PATH}/${ROOT_LABEL}

printf "%s" "Syncing root file system to ROOT partition of SD card ..." 
#execute "tar xvzf ../rootfs.tar.gz -C ${SCRIPT_PATH}/${ROOT_LABEL}"
execute fakeroot rsync -av ${ROOTFS_PATH}/* ${SCRIPT_PATH}/${ROOT_LABEL}/
printf "%s\n" "Ok"

if [ -f ${DEPLOY_PATH}/network/interfaces ] ; then
	printf "%s" "Export network/interfaces ... " 
	execute cp ${DEPLOY_PATH}/network/interfaces ${SCRIPT_PATH}/${ROOT_LABEL}/etc/network/
	printf "%s\n" "Ok"
fi

printf "%s" "Copying MLO (u-boot.min) to SD ..."
execute "cp ${UBOOT_PATH}/${UBOOT_MIN} ${SCRIPT_PATH}/${BOOT_LABEL}/MLO"
printf "%s\n" "OK"

printf "%s" "Copying $UBOOT image to SD..."
execute "cp ${UBOOT_PATH}/${UBOOT} ${SCRIPT_PATH}/${BOOT_LABEL}/u-boot.bin"
printf "%s\n" "OK"

printf "%s" "Copying $UIMAGE image ..."
execute "cp ${DEPLOY_PATH}/${UIMAGE} ${SCRIPT_PATH}/${BOOT_LABEL}/${KERNEL}"
printf "%s\n" "OK"

printf "%s\n" "Creating boot.scr ..."
cat <<EOF > ./boot.cmd
setenv bootargs 'console=ttyO0,115200n8 rootwait root=/dev/mmcblk0p2 rw mem=364M@0x80000000 mem=320M@0x9FC00000 vmalloc=500M  notifyk.vpssm3_sva=0xBF900000 ip=off noinitrd'
fatload mmc 0 0x80009000 uImage
bootm 0x80009000
EOF
mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n 'Execute uImage.bin' -d ./boot.cmd ${SCRIPT_PATH}/${BOOT_LABEL}/boot.scr
rm ./boot.cmd

sync 

printf "%s" "Umouting all parttions ..."
execute "umount ${SCRIPT_PATH}/${BOOT_LABEL}"
execute "umount ${SCRIPT_PATH}/${ROOT_LABEL}"

rm -rf ${SCRIPT_PATH}/${BOOT_LABEL}
rm -rf ${SCRIPT_PATH}/${ROOT_LABEL}

losetup -d ${LOOP0}
losetup -d ${LOOP1}
losetup -d ${LOOP2}

printf "%s\n" "OK"

execute mv $IMAGE $EXPORT_IMAGE
execute sync

printf "%s\n" "SD boot card image is ready!"


