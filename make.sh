#!/bin/bash

rm bin/* >> /dev/null
rm img/* >> /dev/null

nasm -f bin src/boot.asm -o bin/boot.bin
nasm -f bin src/dos.asm -o bin/dos.bin

nasm -f bin prg/snake.asm -o bin/snake.bin
nasm -f bin prg/tetris.asm -o bin/tetris.bin
nasm -f bin prg/big.asm -o bin/big.bin
nasm -f bin prg/test.asm -o bin/test.bin
nasm -f bin prg/readfile.asm -o bin/readfile.bin

dd if=/dev/zero of=img/floppy1440.img count=2880 bs=512
mkfs.fat -F 12 -s 2 img/floppy1440.img

dd if=bin/boot.bin of=img/floppy1440.img conv=notrunc
mcopy -i img/floppy1440.img bin/dos.bin "::DOS.SYS"

mcopy -i img/floppy1440.img bin/tetris.bin "::tetris.bin"
mcopy -i img/floppy1440.img bin/big.bin "::big.bin"
mcopy -i img/floppy1440.img bin/test.bin "::test.bin"
mcopy -i img/floppy1440.img bin/snake.bin "::snake.bin"
mcopy -i img/floppy1440.img bin/readfile.bin "::readfile.bin"
# mcopy -i img/floppy1440.img bin/snake.bin "::test.txt"
mcopy -i img/floppy1440.img nc.txt "::test.txt"
