export SCRIPT_PATH="$PWD"
export EXPORT_PATH="/opt/exports/${BUILD_PURPOSE}/${PRODUCT}.${PRODUCT_RELEASE}/${RELDIR}/${MACHINE}"
export IPK_EXPORT_PATH="/opt/exports/${BUILD_PURPOSE}/${PRODUCT}.${PRODUCT_RELEASE}/${RELDIR}/ipk"
export IMG_PATH="${EXPORT_PATH}/img"
export NFS_PATH="${EXPORT_PATH}/nfs"

export ROOTFS="${PRODUCT}-image.${PRODUCT_RELEASE}-${MACHINE}.tar.gz"
export KMODULES="kmodules.tgz"



export DEPLOY_PATH=${SCRIPT_PATH/scripts/}
DEPLOY_PATH=${DEPLOY_PATH:0:${#DEPLOY_PATH}-1}
export TMPROOTFSDIR="${DEPLOY_PATH}/rootfs"
export UBOOTDIR="${DEPLOY_PATH}/u-boot"

export KERNEL=`readlink ${DEPLOY_PATH}/uImage.bin`


# This function takes one parameter - command to execute
# Run it with disabled output and check the result. In case of fault it will
# stop the script execution and exit
execute ()
{
    $* >/dev/null
    if [ $? -ne 0 ]; then
        echo
        echo "ERROR: executing $*"
        echo
        exit $? 
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
