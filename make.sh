#!/bin/bash

rm -r bin/* 2> /dev/null
rm img/* 2> /dev/null

set -e

echo '	ASM	src/boot.asm'
nasm -f bin src/boot.asm -o bin/boot.bin
echo '	ASM	src/dos.asm'
nasm -f bin src/dos.asm -o bin/dos.bin
echo ''

mkdir bin/games
mkdir bin/demo
mkdir bin/devel

cd prg
for file in *
do
	nasm -f bin "$file" -o ../bin/"${file%.*}.bin"
	echo '	ASM	prg/'$file
done
cd ..

cd bin

mv tetris.bin games/tetris.prg
mv mines.bin games/mines.prg
mv snake.bin games/snake.prg
mv pong.bin games/pong.prg

mv mandel.bin demo/mandel.prg
mv fib.bin demo/fib.prg
mv div.bin demo/div.prg

mv rombasic.bin devel/rombasic.prg

cd ..

dd if=/dev/zero of=img/floppy1440.img count=2880 bs=512 status=none
dd if=/dev/zero of=img/floppy720.img count=1440 bs=512 status=none
dd if=/dev/zero of=img/floppy1200.img count=2400 bs=512 status=none
dd if=/dev/zero of=img/floppy360.img count=720 bs=512 status=none
dd if=/dev/zero of=img/floppy160.img count=320 bs=512 status=none

mkfs.fat -F 12 img/floppy1440.img > /dev/null
mkfs.fat -F 12 img/floppy720.img > /dev/null
mkfs.fat -F 12 img/floppy1200.img > /dev/null
mkfs.fat -F 12 img/floppy360.img > /dev/null
mkfs.fat -F 12 img/floppy160.img -g 1/8 -r 112 -s 2 > /dev/null

echo ''

for img in img/*
do
	num=$(echo "$img" | tr -dc '0-9')

	echo '	IMG	'$img

	cp bin/boot.bin "bin/boot$num.bin"
	dd if="$img" of="bin/boot$num.bin" bs=36 count=1 conv=notrunc status=none
	dd if="bin/boot$num.bin" of="$img" conv=notrunc status=none

	mcopy -i "$img" bin/dos.bin "::DOS.SYS"
	mcopy -i "$img" bin/demo "::DEMO"
	mcopy -i "$img" bin/games "::GAMES"
	mcopy -i "$img" bin/devel "::DEVEL"
done
