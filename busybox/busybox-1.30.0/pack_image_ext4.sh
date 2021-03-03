#! /bin/bash
rm -rf rootfs.ext4
rm -rf fs
dd if=/dev/zero of=./rootfs.ext4 bs=1M count=32
mkfs.ext4 rootfs.ext4
mkdir fs
mount -o loop rootfs.ext4 ./fs
cp -rf ./_install/* ./fs
umount ./fs
gzip --best -c rootfs.ext4 > rootfs.img.gz 
