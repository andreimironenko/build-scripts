#! /bin/sh

source ./buildenv.sh
source ./makerelease.inc

export DEFAULTCMD="default.cmd"
export BOOTCMD="boot.cmd"
export DEFAULTSCR="default.scr"
export BOOTSCR="boot.scr"

echo "Creating and exporting NAND UBIFS image"
echo ""

declare UBI="ubi.img"
declare UBIFS="ubifs.img"
declare UBINIZE="ubinize.cfg"


printf "%s" "Creating ubi.img ..."
if [ -f $UBI ] ; then
execute rm $UBI 
fi

if [ -f $UBIFS ] ; then
execute rm $UBIFS
fi 

execute fakeroot mkfs.ubifs -r $TMPROOTFSDIR -o $UBIFS -m 2048 -e 124KiB -c 1601 --nosquash-rino-perm
execute fakeroot ubinize -o $DEPLOY_PATH/ubi.${PRODUCT}.${PRODUCT_RELEASE}.${MACHINE}.img -m 2048 -p 128KiB -s 512 -O 2048 $UBINIZE
execute mv $DEPLOY_PATH/ubi.${PRODUCT}.${PRODUCT_RELEASE}.${MACHINE}.img $IMG_PATH/
execute rm $UBIFS
execute pushd ${PWD} 
execute cd $IMG_PATH 
execute ln -sf ubi.${PRODUCT}.${PRODUCT_RELEASE}.${MACHINE}.img ${UBI} 
execute popd
printf "%s \n" "Ok"


printf "%s\n" "Making and copying default u-boot env image ..."
mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n 'default environment' -d $UBOOTDIR/$DEFAULTCMD $IMG_PATH/$DEFAULTSCR

printf "%s" "Copying u-boot binaries to $IMG_PATH ..."
execute rsync -av $UBOOTDIR/* $IMG_PATH/
printf "%s \n" "Ok"

