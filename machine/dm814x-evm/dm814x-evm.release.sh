#! /bin/bash

source ./buildenv.sh
source ./makerelease.inc

export DEFAULTCMD="default.cmd"
export BOOTCMD="boot.cmd"
export DEFAULTSCR="default.scr"
export BOOTSCR="boot.scr"

printf "%s\n" "Making and copying default u-boot env image ..."
mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n 'default environment' -d $UBOOTDIR/$DEFAULTCMD $IMG_PATH/$DEFAULTSCR

printf "%s" "Copying u-boot binaries to $IMG_PATH ..."
execute rsync -av $UBOOTDIR/* $IMG_PATH/
printf "%s \n" "Ok"


# Create a link to mksdimage.sh in /usr/share/build folder.
# The buildspawn demon looks for symlinks in this folder and executes the linked 
# scripts on behalf of SUDO

execute pushd ${PWD}
execute cd /usr/share/buildspawn
execute ln -sf ${SCRIPT_PATH}/mksdimage.sh
execute popd

# Now we must wait mksdimage.sh to complete.
# When it completes it will create an image.
attempt_count=0
attempt_count_max=100
sleep_time=3

while [ ! -f $DEPLOY_PATH/${PRODUCT}.${PRODUCT_RELEASE}.sd.img ] ; do

	if [ $attempt_count -lt $attempt_count_max ] ; then
		(( attempt_count ++))
		sleep $sleep_time  
	else
		printf "%s\n" "Timeout: SD card image was not created!"
		exit 192
	fi
done


printf "%s" "Exporting SD card image ..."
execute mv -f $DEPLOY_PATH/${PRODUCT}.${PRODUCT_RELEASE}.sd.img ${IMG_PATH}/
execute pushd ${PWD}
execute cd ${IMG_PATH}
execute ln -sf ${PRODUCT}.${PRODUCT_RELEASE}.sd.img sd.img
execute popd

printf "%s\n" "Ok"	