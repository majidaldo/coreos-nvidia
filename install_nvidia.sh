#!/bin/sh
set -e

mkdir -p /usr/src/kernels
cd       /usr/src/kernels

#get kernel source. recent CoreOS build from plain
#kernel source. that's why this works

curl https://www.kernel.org/pub/linux/kernel/\
v`uname -r | grep -o '^[0-9]'`.x/\
linux-`uname -r | grep -o '[0-9].[0-9].[0-9]'`.tar.xz \
    > linux.tar.xz
mkdir linux
tar -xvf linux.tar.xz -C linux --strip-components=1


# set gcc version used to compile kernel

DRIVER_GCC_VER=$(grep -o -e 'gcc version [0-9].[0-9]' /proc/version | \
		 sed 's/gcc version //')
apt-get update
apt-get install -y gcc-${DRIVER_GCC_VER} g++-${DRIVER_GCC_VER}
update-alternatives --install \
		    /usr/bin/gcc gcc /usr/bin/gcc-${DRIVER_GCC_VER} 60 \
		    --slave \
		    /usr/bin/g++ g++ /usr/bin/g++-${DRIVER_GCC_VER}
#print gcc ver to check
update-alternatives --set gcc "/usr/bin/gcc-${DRIVER_GCC_VER}"

#prepare source for modules

cd linux
zcat /proc/config.gz > .config
make modules_prepare
echo "#define UTS_RELEASE \"$(uname -r)\"" \
    > include/generated/utsrelease.h


# Nvidia drivers setup

cd /opt/nvidia

if [ "$DRIVER_VER" = "CUDA" ];
then
    chmod +x ./cuda.run
    ./cuda.run \
	--silent \
	--driver \
	--kernel-source-path=/usr/src/kernels/linux
else
    chmod +x driver.run
    ./driver.run \
	--silent \
	--kernel-source-path=/usr/src/kernels/linux
fi
modprobe nvidia
#todo: install with --compat32-libdir?


# Nvidia CUDA setup

#use proper gcc
update-alternatives --remove gcc /usr/bin/gcc-${DRIVER_GCC_VER}
update-alternatives --install \
		    /usr/bin/gcc gcc /usr/bin/gcc-${CUDA_GCC_VER} 60 \
		    --slave \
		    /usr/bin/g++ g++ /usr/bin/g++-${CUDA_GCC_VER}
#print gcc ver to check
update-alternatives --config gcc
chmod +x cuda.run
./cuda.run --silent --toolkit --samples

# run samples setup (again.just to get kenerl module nvidia_uvm!)

cd /usr/local/cuda/samples/1_Utilities/deviceQuery
make
./deviceQuery
