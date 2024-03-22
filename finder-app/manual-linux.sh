#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/home/jigar/Documents/LinuxCourse/LinuxImageAssignment
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.1.10
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    echo "mrproper"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    echo "defconfig"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    echo "make all"
    make -j4 ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    # make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
    echo "make dtbs"
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
fi

cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}
echo "Adding the Image in outdir"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
cd ${OUTDIR}
mkdir -p rootfs
cd rootfs
mkdir -p bin dev etc home lib lib64 proc sbin sys tmp usr var
mkdir -p usr/bin usr/lib usr/sbin
mkdir -p var/log

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make distclean
    make defconfig    
else
    cd busybox
fi

# TODO: Make and install busybox
echo "Make and install busybox"
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

echo "Library dependencies"
${CROSS_COMPILE}readelf -a ${OUTDIR}/busybox/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ${OUTDIR}/busybox/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
echo "Add library dependencies to rootfs"
FILE_SRCDIR=$(dirname $(which aarch64-none-linux-gnu-gcc))/..
cp ${FILE_SRCDIR}/aarch64-none-linux-gnu/libc/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/
cp ${FILE_SRCDIR}/aarch64-none-linux-gnu/libc/lib64/libm.so.6 ${OUTDIR}/rootfs/lib64/
cp ${FILE_SRCDIR}/aarch64-none-linux-gnu/libc/lib64/libresolv.so.2 ${OUTDIR}/rootfs/lib64/
cp ${FILE_SRCDIR}/aarch64-none-linux-gnu/libc/lib64/libc.so.6 ${OUTDIR}/rootfs/lib64/

# TODO: Make device nodes
echo "Make device nodes"
cd ${OUTDIR}/rootfs/
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 666 dev/console c 5 1

# TODO: Clean and build the writer utility
echo "Clean Build Writer utility"
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=aarch64-none-linux-gnu-
cp writer ${OUTDIR}/rootfs/home/

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
echo "Copy Scripts"
cp finder.sh ${OUTDIR}/rootfs/home/
cp finder-test.sh ${OUTDIR}/rootfs/home/
cp autorun-qemu.sh ${OUTDIR}/rootfs/home/
cd ..
mkdir -p ${OUTDIR}/rootfs/home/conf
cp conf/assignment.txt ${OUTDIR}/rootfs/home/conf/
cp conf/username.txt ${OUTDIR}/rootfs/home/conf/

# TODO: Chown the root directory
echo "Chown the root directory"
sudo chown -R root:root ${OUTDIR}/rootfs

# TODO: Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
find . | cpio -H newc -ov --owner root:root > ${OUTDIR}/initramfs.cpio
cd ${OUTDIR}
gzip -f initramfs.cpio
echo "Complete all steps"
