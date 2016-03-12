#!/bin/bash

echo "This script installs system configuration and data files from product"
echo "specification config folder."
echo "It will always be a part of makeself self-executing archive."
echo ""
echo "Self-executing archive binary name as follows:"
echo "     config.{PRODUCT}.{PRODUCT_RELEASE}.tar.bz2.run"
echo "the script will check the PRODUCT defined in the script with one from"
echo "the root file system. In case of mismatch it will not start installation"
echo ""
echo "Start installation with this command:"
echo "     config.{PRODUCT}.{PRODUCT_RELEASE}.tar.bz2.run -- /path/to/rootfs "
echo ""
echo "All parameters after [--] will be passed to the installation script."
echo "At the moment, this script only accepts a single argument - path to"
echo "root file system where the files are installed"

ROOT_DIR=$1

printf "%s" "Checking the file system root directory ... "
if [ -z ${ROOT_DIR} ] ; then
	ROOT_DIR="/"
fi
printf "%s\n" "Ok"

# The file system.conf is installed on each product
# It contains some build configuration like PRODUC, PRODUCT_RELEASE, MACHINE and
# etc.
if [ -f ${ROOT_DIR}/etc/system.conf ] ; then
	source ${ROOT_DIR}/etc/system.conf
else
	echo "The required file /etc/system.conf is not found!"
	echo "Quit ..."
	exit 1
fi

# This file below must be defined in pd-products/productid/config folder.
# It must implement BASH function config_install(), where all installation steps
# are implemented, such as copying files to the destination folder,setting 
# permisions and creating symlinks
 
if [ -f product.config.inc ] ; then
	source product.config.inc
else
	echo "The required file product.config.inc is not found!" 
	echo "Quit ..."
	exit 1
fi


if [ "$TARGET_PRODUCT" != "$PRODUCT" ] ; then
	echo "The target root file system has wrong product ID!"
	echo "Quit ..."
	exit 1
fi

echo "Start installation procedure, exported from prdouct.config.inc"
config_install

