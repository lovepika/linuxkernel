#! /bin/bash

qemu-system-x86_64 \
-kernel ${HOME}/kernel/linux-4.9.229/arch/x86/boot/bzImage \
-initrd ${HOME}/kernel/busybox/busybox-1.30.0/rootfs.img.gz \
-append "root=/dev/ram init=/linuxrc" \
-serial file:output.txt

# -kernel ${HOME}/kernel/linux-5.4.82/arch/x86_64/boot/bzImage \
