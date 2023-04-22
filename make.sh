#!/bin/bash

rm bin/* >> /dev/null

nasm -f bin src/boot.asm -o bin/boot.bin
nasm -f bin src/dos.asm -o bin/dos.bin

dd if=/dev/zero of=bin/floppy1440.img count=2880 bs=512
mkfs.fat -F 12 bin/floppy1440.img

dd if=bin/boot.bin of=bin/floppy1440.img conv=notrunc
mcopy -i bin/floppy1440.img bin/dos.bin "::DOS.SYS"
