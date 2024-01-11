#!/bin/bash
qemu-system-i386 -cpu 486 -fda $1
# qemu-system-i386 -cpu 486 -drive file=img/floppy1440.img,index=0,if=floppy,format=raw -drive file=img/floppy720.img,index=1,if=floppy,format=raw
