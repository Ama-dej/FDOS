#!/bin/bash
qemu-system-i386 -cpu 486 -fda $1 -audiodev pa,id=pa1 -machine pcspk-audiodev=pa1 -device AC97,audiodev=pa1
