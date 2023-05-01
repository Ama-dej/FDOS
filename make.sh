#!/bin/bash

rm bin/* >> /dev/null
rm img/* >> /dev/null

nasm -f bin src/boot.asm -o bin/boot.bin
nasm -f bin src/dos.asm -o bin/dos.bin

nasm -f bin prg/snake.asm -o bin/snake.bin

dd if=/dev/zero of=img/floppy1440.img count=2880 bs=512
mkfs.fat -F 12 -s 1 img/floppy1440.img

dd if=bin/boot.bin of=img/floppy1440.img conv=notrunc
mcopy -i img/floppy1440.img bin/dos.bin "::DOS.SYS"

mcopy -i img/floppy1440.img bin/snake.bin "::snake.bin"

mcopy -i img/floppy1440.img bin/boot.bin "::lorem"
mcopy -i img/floppy1440.img bin/boot.bin "::ipsum"
mcopy -i img/floppy1440.img bin/boot.bin "::dolor"
mcopy -i img/floppy1440.img bin/boot.bin "::sit"
mcopy -i img/floppy1440.img bin/boot.bin "::amet"
