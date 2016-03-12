#! /bin/sh
source ./buildenv.sh
source ./makerelease.inc

################################################################################
#  Global variables                                                            #
################################################################################

#Getting our own script name
declare -rx SCRIPT=${0##*/}

declare SCRIPT_PATH=`pwd`
declare DEPLOY_PATH=${SCRIPT_PATH/scripts/}
DEPLOY_PATH=${DEPLOY_PATH:0:${#DEPLOY_PATH}-1}
declare ROOTFS_PATH="$DEPLOY_PATH/rootfs"
declare ROOT_SIZE="0"
declare USER_SIZE="0"
declare USER_LABEL="data"
declare BOOT_LABEL="boot"
declare ROOT_LABEL="linux"

declare UIMAGE="uImage.bin"
declare KERNEL="uImage"
declare UBL="ubl_DM36x_sdmmc_ARM270_DDR216_OSC24.bin"
declare UBOOT="u-boot-dm365-htc.bin"
declare BOOTCMD="boot.cmd"
declare BOOTSCR="boot.scr"

declare LOOP0="/dev/loop0"
declare LOOP1="/dev/loop1"
declare LOOP2="/dev/loop2"
declare EXPORT_IMAGE="${DEPLOY_PATH}/${PRODUCT}.${PRODUCT_RELEASE}-${PRODUCT_VERSION}.sd.img"
declare IMAGE="$DEPLOY_PATH/sd.image"

#Exit's cause
EXIT_SUCCESS=0
EXIT_FAIL_EXECUTEL=192


# The execute function is used to pick up the result of operation and stop the
# execution of the script in case failure. Consider it as an analogue of 
# C/C++ assert
function execute () 
{
	$* >/dev/null
    if [ $? -ne 0 ]; then
        echo
        echo "ERROR: executing $*"
        echo
        exit -1
    fi
}
export -f execute

# This function takes one parameter - command to execute
# Run it with disabled output and check the result. In case of fault it will
# leave that is denoted by capital L.
function executeL ()
{
	#Redirect standard error stream to standard output
	2>&1
	#Store command
	_cmd=$*
	
	#Execute the command
    $* >/dev/null
    
    #Store exit code 
	_exit_code=$?
	
    #Check the return result, if it fails exit
    if [ ${_exit_code} -ne 0 ]; then
        exit_msg="ERROR: executing ${_cmd} returns ${_exit_code}"
		echo ${exit_msg}
        exit $EXIT_FAIL_EXECUTEL
    fi
}
export -f executeL


function exit_handler ()
{
	# Deallocation and cleaning up
	printf "%s" "Unmounting all partitions ..."
	execute umount ${DEPLOY_PATH}/${ROOT_LABEL}
	printf "%s\n" "Ok"

	printf "%s" "Deallocating loop-back devices ... "
	execute losetup -d ${LOOP0}
	execute losetup -d ${LOOP1}
	printf "%s\n" "OK"
	
	printf "%s" "Deleting temproary folder and files ..."
	execute rm -rf ${DEPLOY_PATH}/${ROOT_LABEL}
	printf "%s\n" "Ok"

	if [ -f $IMAGE ] ; then 	
		execute mv $IMAGE $EXPORT_IMAGE
	fi
}
export -f exit_handler 

trap exit_handler EXIT

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

# Default cylinder size
CYLN_SIZE_BYTES=8225280

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

let "DRIVE_SIZE = 2*CYLN_SIZE_BYTES + ROOT_SIZE"
let "DRIVE_SIZE_MBYTES = DRIVE_SIZE / 1024 + 1"
printf "%s" "Total drive size ... $DRIVE_SIZE"
printf "\n"

printf "%s" "Creating sd.image file  "
executeL dd if=/dev/zero of=${IMAGE} bs=1024 count=$DRIVE_SIZE_MBYTES 
 
SD_SIZE=`fdisk -l $IMAGE | grep Disk | awk '{print $5}'`
SD_CYLN=`echo $SD_SIZE/255/63/512 | bc`

echo "Image characteristics:"
echo "    size $SD_SIZE bytes"
echo "    heads 255"
echo "    sectors 63"
echo "    $SD_CYLN cylinders"
echo "    cylinder size $CYLN_SIZE_BYTES bytes"

printf "\n"
printf "%s\n" "Calculating partitions sizes"

printf "%s" "ROOT partition size in cylinders ... "
let "ROOT_SIZE_CYLNS = ROOT_SIZE / CYLN_SIZE_BYTES - 1"
printf "%s\n" "$ROOT_SIZE_CYLNS"

printf "%s" "Creating /dev/loop0 device for whole drive"
executeL losetup ${LOOP0} ${IMAGE}
printf "%s\n" "Ok"


printf "%s" "Creating partition table ..."
{
 echo "2,$ROOT_SIZE_CYLNS,,-"
} | sfdisk --heads 255 --sectors 63 --cylinders $SD_CYLN $LOOP0 > /dev/null


if [ $? -ne 0 ]; then
	err=$?
	echo sfdisk has failed returning $err
	exit $err;
fi
printf "%s\n" "Ok"



printf "%s" "Creating ${LOOP1} device with ROOT partition ... "
executeL losetup ${LOOP1} ${IMAGE} -o $((2*$CYLN_SIZE_BYTES)) --sizelimit $(($ROOT_SIZE_CYLNS * $CYLN_SIZE_BYTES))
executeL mkfs.ext3 -L ${ROOT_LABEL} ${LOOP1}
printf "%s\n" "Ok"

printf "%s" "Copy UBL and U-Boot to the boot cylinder ... "
executeL ../uflash -d $LOOP0 -u ${DEPLOY_PATH}/ubl/${UBL} -b ${DEPLOY_PATH}/${UBOOT} -p DM3XX -vv
printf "%s\n" "Ok"

printf "%s" "Executing mkimage utilty to create a boot.scr file ... "
mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n 'Execute uImage' -d ${DEPLOY_PATH}/${BOOTCMD} ${DEPLOY_PATH}/${BOOTSCR} > /dev/null 
printf "%s\n"

if [ $? -ne 0 ]; then
	err=$?
	echo "Failed to execute mkimage to create boot.scr"
	echo "Execute 'sudo apt-get install uboot-mkimage'"
	exit $err 
fi

printf "%s" "Mount ${LOOP1} device ... "
executeL mkdir -p ${DEPLOY_PATH}/${ROOT_LABEL}
executeL mount ${LOOP1} ${DEPLOY_PATH}/${ROOT_LABEL}
printf "%s\n" "Ok"

printf "%s" "Syncing root file system to ROOT partition of SD card ..." 
executeL fakeroot rsync -av ${ROOTFS_PATH}/* ${DEPLOY_PATH}/${ROOT_LABEL}/
printf "%s\n" "Ok"

printf "%s" "Copying $UIMAGE image ..."
executeL cp ${DEPLOY_PATH}/${UIMAGE} ${DEPLOY_PATH}/${ROOT_LABEL}/boot/uImage
printf "%s\n" "Ok"

printf "%s" "Copying boot.scr, ubl, u-boot and uflash to /boot ... "
executeL cp ${DEPLOY_PATH}/${BOOTSCR} ${DEPLOY_PATH}/${ROOT_LABEL}/boot/
executeL cp ${DEPLOY_PATH}/ubl/${UBL} ${DEPLOY_PATH}/${ROOT_LABEL}/boot/
executeL cp ${DEPLOY_PATH}/${UBOOT} ${DEPLOY_PATH}/${ROOT_LABEL}/boot/
executeL cp ${DEPLOY_PATH}/uflash ${DEPLOY_PATH}/${ROOT_LABEL}/boot/
printf "%s\n" "Ok"

if [ -f ${DEPLOY_PATH}/network/interfaces ] ; then
	printf "%s" "Export network/interfaces ... " 
	execute cp ${DEPLOY_PATH}/network/interfaces ${DEPLOY_PATH}/${ROOT_LABEL}/etc/network/
	printf "%s\n" "Ok"
fi

printf "%s" "Create safemode file under root directory"
executeL touch ${DEPLOY_PATH}/${ROOT_LABEL}/safemode


sync 
printf "%s\n" "SD boot card image is ready!"

exit $EXIT_SUCCESS 

