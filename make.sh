#!/bin/bash

rm -r bin/* >> /dev/null
rm img/* >> /dev/null

nasm -f bin src/boot.asm -o bin/boot.bin
nasm -f bin src/dos.asm -o bin/dos.bin

mkdir bin/games
mkdir bin/test
nasm -f bin prg/snake.asm -o bin/games/snake.prg
nasm -f bin prg/tetris.asm -o bin/games/tetris.prg
nasm -f bin prg/big.asm -o bin/test/velik.prg
nasm -f bin prg/test.asm -o bin/test/test.bin
nasm -f bin prg/readfile.asm -o bin/test/readfile.bin
nasm -f bin prg/div.asm -o bin/test/div.prg
nasm -f bin prg/tobogan.asm -o bin/test/tobogan.bin
nasm -f bin prg/fib.asm -o bin/test/fib.prg
nasm -f bin prg/mines.asm -o bin/games/mines.prg
nasm -f bin prg/mandel.asm -o bin/test/mandel.prg

dd if=/dev/zero of=img/floppy1440.img count=2880 bs=512
mkfs.fat -F 12 img/floppy1440.img
dd if=/dev/zero of=img/floppy720.img count=1440 bs=512
mkfs.fat -F 12 img/floppy720.img
dd if=/dev/zero of=img/floppy1200.img count=2400 bs=512
mkfs.fat -F 12 img/floppy1200.img
dd if=/dev/zero of=img/floppy360.img count=720 bs=512
mkfs.fat -F 12 img/floppy360.img

cp bin/boot.bin bin/boot1440.bin
cp bin/boot.bin bin/boot720.bin
cp bin/boot.bin bin/boot1200.bin
cp bin/boot.bin bin/boot360.bin
dd if=img/floppy1440.img of=bin/boot1440.bin bs=36 count=1 conv=notrunc
dd if=img/floppy720.img of=bin/boot720.bin bs=36 count=1 conv=notrunc
dd if=img/floppy1200.img of=bin/boot1200.bin bs=36 count=1 conv=notrunc
dd if=img/floppy360.img of=bin/boot360.bin bs=36 count=1 conv=notrunc

dd if=bin/boot1440.bin of=img/floppy1440.img conv=notrunc
dd if=bin/boot720.bin of=img/floppy720.img conv=notrunc
dd if=bin/boot1200.bin of=img/floppy1200.img conv=notrunc
dd if=bin/boot360.bin of=img/floppy360.img conv=notrunc

mcopy -i img/floppy1440.img bin/dos.bin "::DOS.SYS"
mcopy -i img/floppy720.img bin/dos.bin "::DOS.SYS"
mcopy -i img/floppy1200.img bin/dos.bin "::DOS.SYS"
mcopy -i img/floppy360.img bin/dos.bin "::DOS.SYS"

# mcopy -i img/floppy1440.img LICENSE "::LICENSE.TXT"
# mcopy -i img/floppy720.img LICENSE "::LICENSE.TXT"
# mcopy -i img/floppy1200.img LICENSE "::LICENSE.TXT"
# mcopy -i img/floppy360.img LICENSE "::LICENSE.TXT"

mcopy -i img/floppy1440.img bin/test "::TEST"
mcopy -i img/floppy1440.img bin/games "::GAMES"
mcopy -i img/floppy1440.img bin/games "::TEST/GAMES"

mcopy -i img/floppy720.img bin/test "::TEST"
mcopy -i img/floppy720.img bin/games "::GAMES"

mcopy -i img/floppy1200.img bin/test "::TEST"
mcopy -i img/floppy1200.img bin/games "::GAMES"

mcopy -i img/floppy360.img bin/test "::TEST"
mcopy -i img/floppy360.img bin/games "::GAMES"
