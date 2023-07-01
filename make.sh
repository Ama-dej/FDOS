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
nasm -f bin prg/abc.asm -o bin/abc.bin
nasm -f bin prg/tobogan.asm -o bin/tobogan.bin

dd if=/dev/zero of=img/floppy1440.img count=2880 bs=512
mkfs.fat -F 12 img/floppy1440.img
# dd if=/dev/zero of=img/floppy720.img count=1440 bs=512
# mkfs.fat -F 12 img/floppy720.img

cp bin/boot.bin bin/boot1440.bin
# cp bin/boot.bin bin/boot720.bin
dd if=img/floppy1440.img of=bin/boot1440.bin bs=36 count=1 conv=notrunc
# dd if=img/floppy720.img of=bin/boot720.bin bs=36 count=1 conv=notrunc

dd if=bin/boot1440.bin of=img/floppy1440.img conv=notrunc
# dd if=bin/boot720.bin of=img/floppy720.img conv=notrunc
mcopy -i img/floppy1440.img bin/dos.bin "::DOS.SYS"
# mcopy -i img/floppy720.img bin/dos.bin "::DOS.SYS"

mcopy -i img/floppy1440.img bin/tetris.bin "::TETRIS.BIN"
mcopy -i img/floppy1440.img bin/big.bin "::BIG.BIN"
mcopy -i img/floppy1440.img bin/test.bin "::TEST.BIN"
mcopy -i img/floppy1440.img bin/snake.bin "::SNAKE.BIN"
mcopy -i img/floppy1440.img bin/readfile.bin "::READFILE.BIN"
# mcopy -i img/floppy1440.img prg/test.txt "::TEST.TXT"
mcopy -i img/floppy1440.img bin/abc.bin "::ABC.BIN"
mcopy -i img/floppy1440.img bin/tobogan.bin "::TOBOGAN.BIN"
mcopy -i img/floppy1440.img src/test.raw "::TEST.RAW"
