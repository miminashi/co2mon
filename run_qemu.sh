#!/bin/sh
qemu-system-arm \
 -M orangepi-pc \
 -m 1024 \
 -cpu cortex-a7 \
 -dtb boot/dtb/sun8i-h3-orangepi-pc.dtb \
 -kernel boot/vmlinuz-5.4.45-sunxi \
 -initrd boot/initrd.img-5.4.45-sunxi \
 -append 'earlyprintk loglevel=8 earlycon=uart8250,mmio32,0x1c28000,115200n8 console=ttyS0 root=/dev/mmcblk0p1' \
 -nographic \
 -serial stdio \
 -monitor none \
 -drive file=armbian_orangepi.img,format=raw,if=none,id=d1 \
 -device sd-card,drive=d1 \
 -nic user,model=allwinner-sun8i-emac,hostfwd=tcp::50022-:22
