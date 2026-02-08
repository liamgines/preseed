#!/bin/bash

usage() {
    echo "Usage: ./seed.sh <debian-amd64-netinst.iso> <preseed.cfg>"
}

WORKING_DIRECTORY="seed"

# https://unix.stackexchange.com/questions/173749/how-to-retroactively-make-a-script-run-as-root
if [[ $EUID -ne 0 ]]; then
    exec sudo /bin/bash "$0" "$@"
    exit 1
fi

if [ $# -lt 1 ]; then
    usage
    echo "ERROR: no iso is provided"
    exit 1
fi

INPUT_DEBIAN_ISO="$1"
shift

if [ $# -lt 1 ]; then
    usage
    echo "ERROR: no config is provided"
    exit 1
fi

PRESEED_CONFIG=$1
shift

OUTPUT_DEBIAN_ISO=seed-$(basename $INPUT_DEBIAN_ISO)

if [ ! -f $INPUT_DEBIAN_ISO ]; then
    echo "ERROR: $INPUT_DEBIAN_ISO could not be found"
	exit 1
fi

if [ ! -f "$PRESEED_CONFIG" ]; then
    echo "ERROR: $PRESEED_CONFIG could not be found"
	exit 1
fi

set -xe

sudo apt install xorriso isolinux -y

sudo rm -rf $WORKING_DIRECTORY/*
sudo mkdir -p $WORKING_DIRECTORY

mkdir -p $WORKING_DIRECTORY/mnt
sudo mount -o loop $INPUT_DEBIAN_ISO $WORKING_DIRECTORY/mnt/

mkdir -p $WORKING_DIRECTORY/copy
cp -rT $WORKING_DIRECTORY/mnt $WORKING_DIRECTORY/copy
sudo umount $WORKING_DIRECTORY/mnt
sudo rm -rf $WORKING_DIRECTORY/mnt/

sudo chmod +w -R $WORKING_DIRECTORY/copy/install.amd/
sudo gunzip $WORKING_DIRECTORY/copy/install.amd/initrd.gz
sudo echo $PRESEED_CONFIG | sudo cpio -H newc -o -A -F $WORKING_DIRECTORY/copy/install.amd/initrd
sudo gzip $WORKING_DIRECTORY/copy/install.amd/initrd
sudo chmod -w -R $WORKING_DIRECTORY/copy/install.amd/

# https://unix.stackexchange.com/questions/532252/how-to-automate-selection-of-type-of-installation-by-editing-isolinux
sudo sed -i "s/append/append auto=true priority=critical file=\/cdrom\/$PRESEED_CONFIG/" $WORKING_DIRECTORY/copy/isolinux/txt.cfg

# https://unix.stackexchange.com/questions/566738/how-to-skip-the-need-to-choose-install-and-hit-enter-in-automated-preseeded
sudo chmod +w $WORKING_DIRECTORY/copy/boot/grub/grub.cfg
sudo printf '\nset default="1"\nset timeout="2"' >> $WORKING_DIRECTORY/copy/boot/grub/grub.cfg
sudo chmod -w $WORKING_DIRECTORY/copy/boot/grub/grub.cfg

MD5SUM="md5sum.txt"
cd $WORKING_DIRECTORY/copy
sudo chmod +w $MD5SUM
find -follow -type f ! -name $MD5SUM -print0 | xargs -0 md5sum > $MD5SUM
sudo chmod -w $MD5SUM
cd -

sudo chmod +w $WORKING_DIRECTORY/copy/isolinux/isolinux.bin
# https://wiki.debian.org/RepackBootableISO
xorriso -as mkisofs -r -V 'Debian amd64 network install' -o $OUTPUT_DEBIAN_ISO -J -joliet-long -cache-inodes -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin -b isolinux/isolinux.bin -c isolinux/boot.cat -boot-load-size 4 -boot-info-table -no-emul-boot -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus $WORKING_DIRECTORY/copy/
sudo chmod -w $WORKING_DIRECTORY/copy/isolinux/isolinux.bin
