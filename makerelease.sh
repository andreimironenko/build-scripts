#!/bin/sh

source ./buildenv.sh
source ./makerelease.inc

declare -rx SCRIPT=${0##*/}

# Local variables
COMMAND_LINE="$@"
COMMAND_COUNT="$#"

##################### Machine specific exports #################################
export_machine () {
printf "%s\n" "Invoking ${MACHINE} specific export release script"
if [ -f ${MACHINE}.release.sh ] ; then
	./${MACHINE}.release.sh 
else
	printf "%s\n" "Warning: ${MACHINE}.release.sh is not found, skip"
fi
}
################################################################################

######################## Product specific script ###############################
export_product () {
printf "%s\n" "Invoking ${PRODUCT} specific export release script"
if [ -f ${PRODUCT}.release.sh ] ; then
	./${PRODUCT}.release.sh 
else
	printf "%s\n" "Warning: ${PRODUCT}.release.sh is not found, skip ..."
fi


}

################################################################################

################################## IPK sync ####################################
export_ipk () {
printf "%s" "Copying ipk packages ..."
execute mkdir -p $IPK_EXPORT_PATH
execute rsync -av ${DEPLOY_PATH}/../../ipk/* $IPK_EXPORT_PATH/
printf "%s \n" "Ok"
}
################################################################################

########################## Exporting rootfs tarball ############################
export_tarball () {
printf "%s" "Exporting root file system tarball ..."
fakeroot tar cvfj ${DEPLOY_PATH}/rootfs.${PRODUCT}.${PRODUCT_RELEASE}.${MACHINE}.tar.bz2 $TMPROOTFSDIR  
execute cp  ${DEPLOY_PATH}/rootfs.${PRODUCT}.${PRODUCT_RELEASE}.${MACHINE}.tar.bz2 $EXPORT_PATH/ 
execute rm ${DEPLOY_PATH}/rootfs.${PRODUCT}.${PRODUCT_RELEASE}.${MACHINE}.tar.bz2 
printf "%s \n" "Ok"
}
################################################################################

######################### Sync NFS rootfs ######################################
export_nfs () {
printf "%s" "Exporting NFS root file system..."
execute mkdir -p $NFS_PATH
execute fakeroot rsync -av $TMPROOTFSDIR/* $NFS_PATH/
execute fakeroot chmod 755 -R $NFS_PATH

if [ "${MACHINE}" = "dm814x-z3" -a "${PRODUCT}" = "iptft" ] ; then
		
	# Add automatic UBIFS mount
	echo "#!/bin/sh"                    				>  $NFS_PATH/etc/init.d/mountubifs.sh 
	echo "if test ! -d \"/media/ubifs\" ; then " 		>> $NFS_PATH/etc/init.d/mountubifs.sh 
	echo "    mkdir \"/media/ubifs\" " 					>> $NFS_PATH/etc/init.d/mountubifs.sh
	echo "fi" 					  						>> $NFS_PATH/etc/init.d/mountubifs.sh
	echo "ubiattach /dev/ubi_ctrl -m 4"					>> $NFS_PATH/etc/init.d/mountubifs.sh
	echo "mount -t ubifs /dev/ubi0_0 /media/ubifs"		>> $NFS_PATH/etc/init.d/mountubifs.sh
	chmod 755 $NFS_PATH/etc/init.d/mountubifs.sh
	
	execute pushd ${PWD} 
	execute cd $NFS_PATH/etc/rc5.d 
	execute ln -sf ../init.d/mountubifs.sh S90mountubifs 
	execute popd
fi

printf "%s \n" "Ok"
}
################################################################################

######################## Export all targets ####################################
export_all () {
	export_machine
	export_product
	export_ipk
	export_tarball
	export_nfs
}

####################  Process command line... ##################################
while [ $# -gt 0 ]; do
  case $1 in
    --help | -h) 
    printf "%s\n"             
    printf "%s\n" "Use $SCRIPT for building export targets and sync them"
    printf "%s\n" "to ${EXPORT_PATH}  "
	printf "%s\n"
	printf "%s\n" "Usage: $SCRIPT [options] [export targets]"
	printf "%s\n"
	printf "%s\n" "Options:"
	printf "%s\n"
	printf "%s\t%s\n" "-l, --list"    "List available export targets" 
	printf "%s\n"
	printf "%s\t%s\n" "-h, --help"    "This help"
	printf "%s\n"
	printf "%s\n" "Examples:"
	printf "%s\n" "To query available export targets"
	printf "%s\n"
	printf "\t%s\n" "$SCRIPT -l"
	printf "%s\n"
	printf "%s\n" "To make machine specific export and ipk sync" 
	printf "%s\n"
	printf "\t%s\n" "$SCRIPT machine ipk"
	printf "%s\n"
	printf "%s\n" "To make all available export targets, suppress any parameter"
	printf "%s\n"
	printf "\t%s\n" "$SCRIPT"
	printf "%s\n"
	exit 0
    ;;
    
    --list| -l)  shift;
    printf "%s\n" "Available export targets:"
    printf "\t%s\t\t%s\n" "Target"   "Description"
    echo "------------------------------------------------------"
    printf "\t%s\t\t%s\n" "machine"  "Machine specific exports"
    printf "\t%s\t\t%s\n" "product"  "Product specific exports"
    printf "\t%s\t\t%s\n" "ipk"      "IPK folder sync"
    printf "\t%s\t\t%s\n" "nfs"      "NFS folder sync"
    printf "\t%s\t\t%s\n" "tarball"   "Creating and exporting rootfs tarball"
    
    exit 0; 
    ;;
        
	-*)     printf "%s\n" "Switch not supported" >&2; exit 1   ;;
	
	*)  EXPORT_TARGETS=($COMMAND_LINE)
		#shift
		break;
		;;  
esac
done


declare YOURUSER=`whoami`
if [ ! "$YOURUSER" = "release" ] ; then 
		echo "Start personal $YOURUSER's release ${PRODUCT_RELEASE} of ${PRODUCT}"
else
		echo "Start an official release ${PRODUCT_RELEASE} of ${PRODUCT}"
fi

printf "%s" "Sanity check of required config and binary files ..."

SANITY_CHECK_STATUS=1

if [ -z "$DEPLOY_PATH/$ROOTFS" ] ; then
   printf "%s\n" "Mandatory root file system image parameter is missed" >&2
   SANITY_CHECK_STATUS=0
fi

if [ -z "$DEPLOY_PATH/$KERNEL" ] ; then
   printf "%s\n" "Mandatory kernel image parameter is missed" >&2
   SANITY_CHECK_STATUS=0
fi

if [ -z "${DEPLOY_PATH}/$KMODULES" ] ; then
   printf "%s\n" "Mandatory kernel modules image parameter is missed" >&2
   SANITY_CHECK_STATUS=0
fi

if [ -z "${DEPLOY_PATH}/$UBOOTDIR" ] ; then
   printf "%s\n" "Mandatory kernel modules image parameter is missed" >&2
   SANITY_CHECK_STATUS=0
fi

if [ "$SANITY_CHECK_STATUS" == 1 ] ; then
  printf "%s\n" "Ok"
else
  printf "%s\n" "Failed"
  exit -137
fi

################## Common configs + creating ROOTFS ############################
			
if [ -d $TMPROOTFSDIR ] ; then

 printf "\n %s" "The folder \"$TMPROOTFSDIR\" exists, overwrite? (Y/N)"
 while  true; do
  read $REPLY
  if [ "$REPLY" = "y" -o "$REPLY" = "Y" ] ; then
    break
  elif [ "$REPLY" = "n" -o "$REPLY" = "N" ] ; then
    echo "Please back-up the existing $TMPROOTFSDIR directory and run the script again"
    exit 0
  else
    echo "Use Y/N:"
    continue
  fi
done
else
	mkdir $TMPROOTFSDIR 
	TAR_OVERRIDE_FLAG=""
fi

printf "%s" "Creating temproary \"$TMPROOTFSDIR\" directory ..."
printf "%s \n" "Ok"

printf "%s" "Untar rootfs tarball ..."
execute fakeroot tar xvfz ${DEPLOY_PATH}/$ROOTFS -C $TMPROOTFSDIR 
printf "%s \n" "Ok"

printf "%s" "Untar kernel module tarball ..." 
execute fakeroot tar xvfz ${DEPLOY_PATH}/$KMODULES -C $TMPROOTFSDIR 
printf "%s \n" "Ok" 

printf "%s" "Creating $IMG_PATH directory ..."
execute mkdir -p $IMG_PATH
printf "%s \n" "Ok"

printf "%s" "Creating data.${PRODUCT}.${PRODUCT_RELEASE}.zip file ... "
if [ -d ${OEBASE}/pd-products/${PRODUCT}/data ] ; then
	execute pushd ${PWD}
	execute cd ${OEBASE}/pd-products/${PRODUCT}/data 
	execute zip -r data.${PRODUCT}.${PRODUCT_RELEASE}.zip *
	execute mv  data.${PRODUCT}.${PRODUCT_RELEASE}.zip ${IMG_PATH}/
	#Copying data ZIP file to rootfs
	execute cp ${IMG_PATH}/data.${PRODUCT}.${PRODUCT_RELEASE}.zip ${TMPROOTFSDIR}/boot/data.zip
	execute popd 
	printf "%s\n" "Ok"
else
	printf "%s\n" "Skipped" c
	printf "%s\n" "Warning: Directory pd-products/${PRODUCT}/data is not found"
fi

printf "%s" "Creating config.${PRODUCT}.${PRODUCT_RELEASE}.tar.bz2.run file ... "
if [ -d ${OEBASE}/pd-products/${PRODUCT}/config ] ; then
	execute rm -rf ../config
	execute mkdir  ../config
	execute cp ./product.config.install.sh ../config/
	execute chmod 744 ../config/product.config.install.sh
	execute rsync -av ${OEBASE}/pd-products/${PRODUCT}/config/* ../config/
	execute makeself --bzip2 --nox11 --quiet ../config config.${PRODUCT}.${PRODUCT_RELEASE}.tar.bz2.run "Configurations"  ./product.config.install.sh 
	execute mv config.${PRODUCT}.${PRODUCT_RELEASE}.tar.bz2.run ${IMG_PATH}/
	
	# Install configuration files in temp. root file system
	execute ${IMG_PATH}/config.${PRODUCT}.${PRODUCT_RELEASE}.tar.bz2.run -- ${TMPROOTFSDIR}

	printf "%s\n" "Ok"
else
	printf "%s\n" "Skipped" 
	printf "%s\n" "Warning: Directory pd-products/${PRODUCT}/data is not found"
fi


printf "%s" "Copying $KERNEL ..."
execute "cp ${DEPLOY_PATH}/$KERNEL $IMG_PATH/" 
execute pushd ${PWD} 
execute cd $IMG_PATH 
execute ln -sf $KERNEL uImage 
execute popd
printf "%s \n" "Ok"

printf "%s" "Copying product.version to export folder ..."
execute cp $DEPLOY_PATH/product.version  $EXPORT_PATH/
printf "%s \n" "Ok"

printf "%s" "Export opkg status file..."
if [ ! -d  $IPK_EXPORT_PATH ] ; then
	execute mkdir -p $IPK_EXPORT_PATH/$MACHINE
fi 
cat $TMPROOTFSDIR/usr/lib/opkg/status >> $IPK_EXPORT_PATH/$MACHINE/opkg.status   
printf "%s \n" "Ok"

if [ "${#EXPORT_TARGETS[@]}" -eq "0" ] ; then
	export_all
else 
for (( i=0; i < ${#EXPORT_TARGETS[@]}; i ++ )); do
	 case ${EXPORT_TARGETS[$i]} in
		
		machine)
			export_machine
			;;

		product)
			export_machine
			export_product
			;;
	
		ipk)
			export_machine
			export_product
			export_ipk
			;;
	
		tarball)
			export_machine
			export_product
			export_tarball
			;;
	
		nfs)
			export_machine
			export_product
			export_nfs
			;;
		*)
			printf "%s\n" "Unknown export target EXPORT_TARGETS[$i]=${EXPORT_TARGETS[$i]}"
		exit -1;
		;;
	 esac
	done

fi	
				
echo "----------------------------------------------------------------------"
echo "All done, all images are copied into $EXPORT_PATH"
echo "----------------------------------------------------------------------"
