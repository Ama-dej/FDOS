#!/bin/bash

rm -r bin/* >> /dev/null
rm img/* >> /dev/null

nasm -f bin src/boot.asm -o bin/boot.bin
nasm -f bin src/dos.asm -o bin/dos.bin

mkdir bin/games
mkdir bin/demo

cd prg
for file in *
do
	nasm -f bin "$file" -o ../bin/"${file%.*}.bin"
done
cd ..

cd bin
mv tetris.bin games/tetris.prg
mv mines.bin games/mines.prg
mv snake.bin games/snake.prg

mv mandel.bin demo/mandel.prg
mv fib.bin demo/fib.prg
mv div.bin demo/div.prg
cd ..

dd if=/dev/zero of=img/floppy1440.img count=2880 bs=512
dd if=/dev/zero of=img/floppy720.img count=1440 bs=512
dd if=/dev/zero of=img/floppy1200.img count=2400 bs=512
dd if=/dev/zero of=img/floppy360.img count=720 bs=512

for img in img/*
do
	mkfs.fat -F 12 "$img"

	num=$(echo "$img" | tr -dc '0-9')

	cp bin/boot.bin "bin/boot$num.bin"
	dd if="$img" of="bin/boot$num.bin" bs=36 count=1 conv=notrunc
	dd if="bin/boot$num.bin" of="$img" conv=notrunc

	mcopy -i "$img" bin/dos.bin "::DOS.SYS"
	mcopy -i "$img" bin/demo "::DEMO"
	mcopy -i "$img" bin/games "::GAMES"
done
