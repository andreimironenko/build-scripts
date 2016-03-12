source ./buildenv.sh
source ./makerelease.inc

declare UBL="ubl_DM36x_sdmmc_ARM270_DDR216_OSC24.bin"
declare UBOOT="u-boot-dm365-evm.bin"
declare BOOTSCR="boot.scr"

printf "%s" "Building SD card image ... "
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

while [ ! -f $DEPLOY_PATH/${PRODUCT}.${PRODUCT_RELEASE}-${PRODUCT_VERSION}.sd.img ] ; do

	if [ $attempt_count -lt $attempt_count_max ] ; then
		(( attempt_count ++))
		sleep $sleep_time  
	else
		printf "%s\n" "Failed"
		printf "%s\n" "Timeout: SD card image was not created!"
		exit 192
	fi
done
printf "%s\n" "Ok"


printf "%s" "Exporting SD card image ..."
execute mv -f $DEPLOY_PATH/${PRODUCT}.${PRODUCT_RELEASE}-${PRODUCT_VERSION}.sd.img ${IMG_PATH}/
execute pushd ${PWD}
execute cd ${IMG_PATH}
execute ln -sf ${PRODUCT}.${PRODUCT_RELEASE}-${PRODUCT_VERSION}.sd.img sd.img
execute popd
printf "%s\n" "Ok"

printf "%s" "Exporting ubl, u-boot and uflash ... "
execute cp ${DEPLOY_PATH}/ubl/${UBL}   ${IMG_PATH}/
execute cp ${DEPLOY_PATH}/${UBOOT}     ${IMG_PATH}/
execute cp ${DEPLOY_PATH}/${BOOTSCR}   ${IMG_PATH}/
execute pushd ${PWD}
execute cd ${IMG_PATH}
execute ln -sf ${UBL} ubl
execute ln -sf ${UBOOT} u-boot.bin
execute popd
printf "%s\n" "Ok"	